#!/usr/bin/env bash
                                                                                                            
export CPPFLAGS="$CPPFLAGS -D FISOC_MPI"
#export FISOC_MPI="yes"

export FFLAGS="$FFLAGS -fbacktrace -g -O0 -fbounds-check -Wall"
#export FFLAGS=" -O0 -g -fbacktrace -fcheck=all" # -Wall -debug -DD  -O0" # -inline-debug-info"
#export FFLAGS=" -g -check all -fpe0 -warn -traceback -debug extended"
#export FFLAGS=" -O3 -xHost " #-ipo"

## optionally over-write the default executable name:
#export FISOC_EXE="FISOC_caller"

export FISOC_ISM="dummy"
export FISOC_ISM_LIBS=""
export FISOC_ISM_LIBPATH="$HOME"
export FISOC_ISM_INCLUDE="$HOME"

#export FISOC_ISM="FOOL"
#export FISOC_ISM_LIBS=""
#export FISOC_ISM_LIBPATH="$HOME"
#export FISOC_ISM_INCLUDE="$HOME"

#export FISOC_ISM="FISh"
#export FISOC_ISM_LIBS="-lFISh"
#export FISOC_ISM_LIBPATH="/usr/local/lib"
#export FISOC_ISM_INCLUDE="$HOME"

#export FISOC_ISM="Elmer"
#export FISOC_ISM_LIBS="-lelmersolver -lmatc -lfhuti -larpack -lparpack"
#export FISOC_ISM_INCLUDE="$ELMER_HOME/share/elmersolver/include"
#export FISOC_ISM_LIBPATH="$ELMER_HOME/lib/elmersolver/"
export FISOC_ISM_GEOM="FISOC_ISM_MESH"

export FISOC_AM="dummy"
export FISOC_AM_LIBS=""
export FISOC_AM_LIBPATH="$HOME"
export FISOC_AM_INCLUDE="$HOME"

export FISOC_OM="dummy"
export FISOC_OM_LIBS=""
export FISOC_OM_INCLUDE="$HOME"
export FISOC_OM_LIBPATH="$HOME"

#export MY_ROMS_DIR="/home/elmeruser/Source/ROMSIceShelf_devel_MISOMIP"
#export FISOC_OM="ROMS"
#export FISOC_OM_LIBS="-loceanM"
#export FISOC_OM_INCLUDE="${MY_ROMS_DIR}/Build"
#export FISOC_OM_LIBPATH="/usr/local/lib/"
export FISOC_OM_GEOM="FISOC_OM_GRID"

# These ROMS_ preprocessor keywords correspond to a relevant subset of 
# the preprocessor keywords in the ROMS .in file.
#export CPPFLAGS="$CPPFLAGS -D ROMS_SPHERICAL"
#export CPPFLAGS="$CPPFLAGS -D ROMS_MASKING"
#export CPPFLAGS="$CPPFLAGS -D ROMS_AVERAGES"
#export CPPFLAGS="$CPPFLAGS -D ROMS_DDDT"
#export CPPFLAGS="$CPPFLAGS -D ROMS_DSDT"
#export CPPFLAGS="$CPPFLAGS -D ROMS_DRAFT"

export ESMFMKFILE="/home/elmeruser/Source/esmf/DEFAULTINSTALLDIR/lib/libO/Linux.gfortran.64.openmpi.default/esmf.mk"

make clean
make install

#rm PET*Log

# to run, for example:
# mpirun -np 4 FISOC_caller

