!> Standalone test driver for the NEGF solver.
!! Reads H, S, K matrices from Matrix Market files, runs the NEGF
!! Fermi level search, and writes the resulting density matrix to a file.
!! This bypasses the CheSS sparse matrix layer entirely.
program test_negf_driver
  use bigpoly, only: set_negf_parameters
  use bigpoly_negf, only: scf_solve, scf_params_t
  use futile
  use datatypesmodule, only: ntreal
  use loadbalancermodule, only: permutematrix, undopermutematrix
  use matrixconversionmodule, only: snapmatrixtosparsitypattern
  use permutationmodule, only: permutation_t, constructdefaultpermutation, &
                               destructpermutation
  use processgridmodule, only: constructprocessgrid, destructprocessgrid
  use psmatrixmodule, only: matrix_ps, constructmatrixfrommatrixmarket, &
                            writematrixtomatrixmarket, destructmatrix
  use mpi
  implicit none

  integer :: iproc, nproc, comm, ierr, ii
  type(matrix_ps) :: H, S, K, H_re, S_re, K_re, K_out
  integer :: regions(5)
  integer, dimension(:), allocatable :: order
  type(permutation_t) :: perm
  type(scf_params_t) :: scf_params
  real(ntreal) :: mu, mu_final
  logical :: converged
  integer :: num_iterations

  type(dictionary), pointer :: parsed, input_dict, negf_dict

  call mpi_init(ierr)
  comm = MPI_COMM_WORLD
  call mpi_comm_rank(comm, iproc, ierr)
  call mpi_comm_size(comm, nproc, ierr)

  ! Initialize futile
  call f_lib_initialize()

  ! Parse the BigDFT input file the same way BigDFT does:
  ! yaml_parse_from_file returns a list of YAML documents,
  ! the actual dictionary is document 0.
  ! Expected structure in input.yaml:
  !   chess:
  !     libnegf:
  !       regions: [24, 32, 40, 48, 56]
  !       reorder: [16, 17, ...]
  !       mu: -0.145
  !       mu_iter: 15
  !       mu_tol: 0.001
  !       estep: 0.001
  !       kbt_dm: 0.001
  !       kbt_t: 0.001
  !       ec: 2.0
  call yaml_parse_from_file(parsed, 'input.yaml')
  input_dict => parsed // 0
  negf_dict => input_dict // 'chess' // 'libnegf'
  call set_negf_parameters(negf_dict)

  ! Set up the NTPoly process grid
  call constructprocessgrid(comm)

  ! Read matrices from Matrix Market files
  call constructmatrixfrommatrixmarket(H, 'H.mtx')
  call constructmatrixfrommatrixmarket(S, 'S.mtx')
  call constructmatrixfrommatrixmarket(K, 'K.mtx')

  ! Read parameters from the dictionary
  allocate(order(K%actual_matrix_dimension))
  regions = negf_dict // 'regions'
  order = negf_dict // 'reorder'
  mu = negf_dict // 'mu'

  ! Build the permutation for device/contact reordering
  call constructdefaultpermutation(perm, H%logical_matrix_dimension)
  perm%index_lookup(:size(order)) = order + 1
  do ii = 1, H%actual_matrix_dimension
    perm%reverse_index_lookup(ii) = perm%index_lookup(ii)
  end do

  ! Permute matrices into device/contact block ordering
  call permutematrix(H, H_re, perm)
  call permutematrix(S, S_re, perm)
  call permutematrix(K, K_re, perm)
  call snapmatrixtosparsitypattern(H_re, K_re)
  call snapmatrixtosparsitypattern(S_re, K_re)

  ! Set up SCF parameters
  scf_params%max_iterations = negf_dict // 'mu_iter'
  scf_params%tolerance = negf_dict // 'mu_tol'
  scf_params%bracket_width = 0.1d0
  scf_params%mu_initial = mu

  ! Run the NEGF Fermi level search
  call scf_solve(iproc, H_re, S_re, K_re, regions, &
                 scf_params, mu_final, converged, num_iterations)

  ! Undo permutation and write result
  call undopermutematrix(K_re, K_out, perm)
  call writematrixtomatrixmarket(K_out, 'K_negf.mtx')

  if (iproc == 0) then
    call yaml_map('Converged', converged)
    call yaml_map('Final mu', mu_final)
    call yaml_map('Iterations', num_iterations)
  end if

  ! Cleanup
  deallocate(order)
  call destructmatrix(H)
  call destructmatrix(S)
  call destructmatrix(K)
  call destructmatrix(K_out)
  call destructpermutation(perm)
  call destructprocessgrid()
  call dict_free(parsed)
  call f_lib_finalize()
  call mpi_finalize(ierr)

end program test_negf_driver
