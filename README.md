BigDFT-Suite tutorial

This branch is created to better understand how BigDFT works and how to generate an input file, how to perform geometry optimization and dynamic simulation.
This guide is a work in progress therefore, much of the documentation is currently provided through comments in inputfiles or into scripts.
For a more in depth explanation of how to use the software, please refer to the official documentation: https://l_sim.gitlab.io/bigdft-suite/index.html.

BigDFT-Suite is designed to work closely with PyBigDFT. PyBigDFT is a Python library that uses the software components and modules provided by BigDFT-Suite to set up and launch simulations, as well as to visualize molecular and atomic structures. All scripts can be executed directly from their respective directories using: python script.py


Automated installation of Bigdft-Suite and LibNEGF

To simplify the installation and integration of BigDFT-Suite and libNEGF, the real_installer.sh script has been developed. This Bash script automates the configuration, compilation, and installation of both software packages, including the steps required to link libNEGF with BigDFT.
It also handles the configuration of compiler paths, external libraries, and environment variables required by the build process, reducing the need for manual intervention and helping ensure a consistent installation.
Further details about the installation procedure, dependencies, environment configuration, and required modifications can be found in installation_all/README.md.
