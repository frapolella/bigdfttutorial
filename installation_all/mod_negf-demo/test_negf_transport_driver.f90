! Fixed-H finite-bias transport driver for BigDFT Matrix Market matrices.
program test_negf_transport_driver
  use futile
  use datatypesmodule, only: ntreal
  use libnegf, only: Tnegf, lnParams, init_negf, set_mpi_bare_comm, create_HS, &
                     set_h, set_s, init_contacts, init_structure, get_params, &
                     set_params, compute_current, destroy_negf, eovh
  use loadbalancermodule, only: permutematrix
  use permutationmodule, only: permutation_t, constructdefaultpermutation, &
                               destructpermutation
  use processgridmodule, only: constructprocessgrid, destructprocessgrid
  use psmatrixmodule, only: matrix_ps, constructmatrixfrommatrixmarket, &
                            destructmatrix, convertmatrixtocomplex, gathermatrixtoprocess
  use smatrixmodule, only: matrix_lsc
  use mpi
  implicit none

  integer :: iproc, nproc, comm, ierr, ii, unit
  integer :: regions(5), nrow
  integer, allocatable :: order(:)
  real(ntreal) :: mu_left, mu_right, kbt, emin, emax, estep, spin_degeneracy
  real(ntreal) :: current_amp
  type(matrix_ps) :: H, S, H_reordered, S_reordered, H_complex, S_complex
  type(matrix_lsc) :: H_local, S_local
  type(permutation_t) :: perm
  type(Tnegf), target :: negf
  type(lnParams) :: params
  type(dictionary), pointer :: parsed, input_dict, negf_dict

  call MPI_Init(ierr)
  comm = MPI_COMM_WORLD
  call MPI_Comm_rank(comm, iproc, ierr)
  call MPI_Comm_size(comm, nproc, ierr)
  call f_lib_initialize()
  call yaml_parse_from_file(parsed, 'input.yaml')
  input_dict => parsed // 0
  negf_dict => input_dict // 'chess' // 'libnegf'

  regions = negf_dict // 'regions'
  mu_left = negf_dict // 'mu_left'
  mu_right = negf_dict // 'mu_right'
  kbt = negf_dict // 'kbt_t'
  emin = negf_dict // 'emin'
  emax = negf_dict // 'emax'
  estep = negf_dict // 'estep'
  spin_degeneracy = negf_dict // 'spin_degeneracy'

  call constructprocessgrid(comm)
  call constructmatrixfrommatrixmarket(H, 'H.mtx')
  call constructmatrixfrommatrixmarket(S, 'S.mtx')

  nrow = H%actual_matrix_dimension
  allocate(order(nrow))
  order = negf_dict // 'reorder'
  if (H%logical_matrix_dimension /= S%logical_matrix_dimension .or. &
      H%actual_matrix_dimension /= S%actual_matrix_dimension) then
    error stop 'H and S matrix dimensions differ'
  end if
  if (size(order) /= nrow) error stop 'reorder length does not match matrix size'
  if (regions(5) /= nrow) error stop 'final region boundary does not match matrix size'
  if (regions(1) <= 0) error stop 'region boundaries must be positive'
  if (any(regions(2:5) <= regions(1:4))) error stop 'regions must be strictly increasing'
  if (kbt <= 0.0_ntreal .or. estep <= 0.0_ntreal .or. emax <= emin) then
    error stop 'invalid temperature or energy grid'
  end if

  call constructdefaultpermutation(perm, H%logical_matrix_dimension)
  perm%index_lookup(:size(order)) = order + 1
  do ii = 1, H%actual_matrix_dimension
    perm%reverse_index_lookup(ii) = perm%index_lookup(ii)
  end do
  call permutematrix(H, H_reordered, perm)
  call permutematrix(S, S_reordered, perm)

  call convertmatrixtocomplex(H_reordered, H_complex)
  call convertmatrixtocomplex(S_reordered, S_complex)
  call gathermatrixtoprocess(H_complex, H_local)
  call gathermatrixtoprocess(S_complex, S_local)

  call init_negf_with_mpi(negf)
  call create_HS(negf, 1)
  call set_h(negf, H_local%rows, H_local%values, H_local%inner_index, H_local%outer_index + 1)
  call set_s(negf, S_local%rows, S_local%values, S_local%inner_index, S_local%outer_index + 1)
  call init_contacts(negf, 2)

  ! Match the Chain partition: device, left contact layers, right contact layers.
  block
    integer :: surfstart(2), surfend(2), contend(2), plend(1)
    integer, allocatable :: cblk(:)
    allocate(cblk(2))
    plend = [regions(1)]
    surfstart = [regions(1) + 1, regions(3) + 1]
    surfend = [regions(1), regions(3)]
    contend = [regions(3), regions(5)]
    cblk = 1
    call init_structure(negf, 2, surfstart, surfend, contend, 1, plend, cblk)
    deallocate(cblk)
  end block

  call get_params(negf, params)
  params%mu(1:2) = [mu_left, mu_right]
  params%kbT_t(1:2) = kbt
  params%kbT_dm(1:2) = kbt
  params%Emin = emin
  params%Emax = emax
  params%Estep = estep
  params%g_spin = spin_degeneracy
  params%eneconv = 1.0_ntreal
  call set_params(negf, params)

  call compute_current(negf)
  call MPI_Allreduce(MPI_IN_PLACE, negf%tunn_mat, size(negf%tunn_mat), &
                     MPI_DOUBLE_PRECISION, MPI_SUM, comm, ierr)
  call MPI_Allreduce(MPI_IN_PLACE, negf%currents, size(negf%currents), &
                     MPI_DOUBLE_PRECISION, MPI_SUM, comm, ierr)
  current_amp = negf%currents(1) * eovh

  if (iproc == 0) then
    open(newunit=unit, file='transmission.dat', status='replace', action='write')
    do ii = 1, size(negf%tunn_mat, 1)
      write(unit, '(ES24.16,2X,ES24.16)') emin + real(ii - 1, ntreal) * estep, &
                                         negf%tunn_mat(ii, 1)
    end do
    close(unit)

    open(newunit=unit, file='transport_result.txt', status='replace', action='write')
    write(unit, '(A,ES24.16)') 'mu_left_hartree=', mu_left
    write(unit, '(A,ES24.16)') 'mu_right_hartree=', mu_right
    write(unit, '(A,ES24.16)') 'current_contact_pair_1_to_2_amp=', current_amp
    write(unit, '(A,ES24.16)') 'current_contact_pair_1_to_2_nA=', current_amp * 1.0e9_ntreal
    write(unit, '(A,I0)') 'transmission_points=', size(negf%tunn_mat, 1)
    write(unit, '(A)') 'potential_profile=not applied; H and S are frozen from the GS'
    close(unit)
  end if

  call destroy_negf(negf)
  call destructmatrix(H)
  call destructmatrix(S)
  call destructmatrix(H_reordered)
  call destructmatrix(S_reordered)
  call destructmatrix(H_complex)
  call destructmatrix(S_complex)
  call destructpermutation(perm)
  call destructprocessgrid()
  deallocate(order)
  call dict_free(parsed)
  call f_lib_finalize()
  call MPI_Finalize(ierr)

contains

  subroutine init_negf_with_mpi(instance)
    use mpi_f08
    type(Tnegf), intent(inout) :: instance
    call init_negf(instance)
    call set_mpi_bare_comm(instance, MPI_COMM_WORLD)
  end subroutine init_negf_with_mpi

end program test_negf_transport_driver
