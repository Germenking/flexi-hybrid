!=================================================================================================================================
! Copyright (c) 2010-2017 Prof. Claus-Dieter Munz
! Copyright (c) 2016-2017 Gregor Gassner (github.com/project-fluxo/fluxo)
! Copyright (c) 2016-2017 Florian Hindenlang (github.com/project-fluxo/fluxo)
! Copyright (c) 2016-2017 Andrew Winters (github.com/project-fluxo/fluxo)
! This file is part of FLEXI, a high-order accurate framework for numerically solving PDEs with discontinuous Galerkin methods.
! For more information see https://www.flexi-project.org and https://nrg.iag.uni-stuttgart.de/
!
! FLEXI is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
! as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
!
! FLEXI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with FLEXI. If not, see <http://www.gnu.org/licenses/>.
!=================================================================================================================================
#include "flexi.h"
#include "eos.h"
!==================================================================================================================================
!> Contains routines to compute the riemann (Advection, Diffusion) for a given Face
!==================================================================================================================================
MODULE MOD_Riemann
! MODULES
IMPLICIT NONE
PRIVATE
!----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
ABSTRACT INTERFACE
  PPURE SUBROUTINE RiemannInt(F_L,F_R,U_LL,U_RR,F)
    REAL,DIMENSION(PP_2Var),INTENT(IN) :: U_LL,U_RR
    REAL,DIMENSION(PP_nVar),INTENT(IN) :: F_L,F_R
    REAL,DIMENSION(PP_nVar),INTENT(OUT):: F
  END SUBROUTINE
END INTERFACE

PROCEDURE(RiemannInt),POINTER :: Riemann_pointer    !< pointer defining the standard inner Riemann solver
PROCEDURE(RiemannInt),POINTER :: RiemannBC_pointer  !< pointer defining the standard BC    Riemann solver

INTEGER,PARAMETER      :: PRM_RIEMANN_SAME          = -1
INTEGER,PARAMETER      :: PRM_RIEMANN_LF            = 1
INTEGER,PARAMETER      :: PRM_RIEMANN_HLLC          = 2
INTEGER,PARAMETER      :: PRM_RIEMANN_ROE           = 3
INTEGER,PARAMETER      :: PRM_RIEMANN_ROEL2         = 32
INTEGER,PARAMETER      :: PRM_RIEMANN_ROEENTROPYFIX = 33
INTEGER,PARAMETER      :: PRM_RIEMANN_HLL           = 4
INTEGER,PARAMETER      :: PRM_RIEMANN_HLLE          = 5
INTEGER,PARAMETER      :: PRM_RIEMANN_HLLEM         = 6
#ifdef SPLIT_DG
INTEGER,PARAMETER      :: PRM_RIEMANN_CH            = 7
INTEGER,PARAMETER      :: PRM_RIEMANN_Average       = 0
#endif

INTERFACE InitRiemann
  MODULE PROCEDURE InitRiemann
END INTERFACE

INTERFACE Riemann
  MODULE PROCEDURE Riemann_Point
  MODULE PROCEDURE Riemann_Side
END INTERFACE

#if PARABOLIC
INTERFACE ViscousFlux
  MODULE PROCEDURE ViscousFlux_Point
  MODULE PROCEDURE ViscousFlux_Side
END INTERFACE
#endif

INTERFACE FinalizeRiemann
  MODULE PROCEDURE FinalizeRiemann
END INTERFACE


PUBLIC::DefineParametersRiemann
PUBLIC::InitRiemann
PUBLIC::Riemann
PUBLIC::FinalizeRiemann
#if PARABOLIC
PUBLIC::ViscousFlux
#endif
!==================================================================================================================================

CONTAINS


!==================================================================================================================================
!> Define parameters
!==================================================================================================================================
SUBROUTINE DefineParametersRiemann()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: prms,addStrListEntry
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================
CALL prms%SetSection("Riemann")
CALL prms%CreateIntFromStringOption('Riemann',   "Riemann solver to be used: LF, HLLC")
CALL addStrListEntry('Riemann','lf',           PRM_RIEMANN_LF)
CALL addStrListEntry('Riemann','hllc',         PRM_RIEMANN_HLLC)
#ifdef SPLIT_DG
CALL addStrListEntry('Riemann','ch',           PRM_RIEMANN_CH)
CALL addStrListEntry('Riemann','avg',          PRM_RIEMANN_Average)
#endif
CALL prms%CreateIntFromStringOption('RiemannBC', "Riemann solver used for boundary conditions: Same, LF, HLLC")
CALL addStrListEntry('RiemannBC','lf',           PRM_RIEMANN_LF)
CALL addStrListEntry('RiemannBC','hllc',         PRM_RIEMANN_HLLC)
#ifdef SPLIT_DG
CALL addStrListEntry('RiemannBC','ch',           PRM_RIEMANN_CH)
CALL addStrListEntry('RiemannBC','avg',          PRM_RIEMANN_Average)
#endif
CALL addStrListEntry('RiemannBC','same',         PRM_RIEMANN_SAME)
END SUBROUTINE DefineParametersRiemann

!==================================================================================================================================!
!> Initialize Riemann solver routines, read inner and BC Riemann solver parameters and set pointers
!==================================================================================================================================!
SUBROUTINE InitRiemann()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: GETINTFROMSTR
!----------------------------------------------------------------------------------------------------------------------------------
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                 :: Riemann
!==================================================================================================================================
#ifndef SPLIT_DG
Riemann = GETINTFROMSTR('Riemann')
SELECT CASE(Riemann)
CASE(PRM_RIEMANN_LF)
  Riemann_pointer => Riemann_LF
CASE(PRM_RIEMANN_HLLC)
  Riemann_pointer => Riemann_HLLC
CASE DEFAULT
  CALL CollectiveStop(__STAMP__,&
    'Riemann solver not defined!')
END SELECT

Riemann = GETINTFROMSTR('RiemannBC')
SELECT CASE(Riemann)
CASE(PRM_RIEMANN_SAME)
  RiemannBC_pointer => Riemann_pointer
CASE(PRM_RIEMANN_LF)
  RiemannBC_pointer => Riemann_LF
CASE(PRM_RIEMANN_HLLC)
  RiemannBC_pointer => Riemann_HLLC
CASE DEFAULT
  CALL CollectiveStop(__STAMP__,&
    'RiemannBC solver not defined!')
END SELECT

#else
Riemann = GETINTFROMSTR('Riemann')
SELECT CASE(Riemann)
CASE(PRM_RIEMANN_LF)
  Riemann_pointer => Riemann_LF
CASE(PRM_RIEMANN_CH)
  Riemann_pointer => Riemann_CH
CASE(PRM_RIEMANN_Average)
  Riemann_pointer => Riemann_FluxAverage
CASE DEFAULT
  CALL CollectiveStop(__STAMP__,&
    'Riemann solver not defined!')
END SELECT

Riemann = GETINTFROMSTR('RiemannBC')
SELECT CASE(Riemann)
CASE(PRM_RIEMANN_SAME)
  RiemannBC_pointer => Riemann_pointer
CASE(PRM_RIEMANN_LF)
  RiemannBC_pointer => Riemann_LF
CASE(PRM_RIEMANN_CH)
  Riemann_pointer => Riemann_CH
CASE(PRM_RIEMANN_Average)
  RiemannBC_pointer => Riemann_FluxAverage
CASE DEFAULT
  CALL CollectiveStop(__STAMP__,&
    'RiemannBC solver not defined!')
END SELECT
#endif /*SPLIT_DG*/
END SUBROUTINE InitRiemann

!==================================================================================================================================
!> Computes the numerical flux for a side calling the flux calculation pointwise.
!> Conservative States are rotated into normal direction in this routine and are NOT backrotated: don't use it after this routine!!
!> Attention 2: numerical flux is backrotated at the end of the routine!!
!==================================================================================================================================
SUBROUTINE Riemann_Side(Nloc,FOut,U_L,U_R,UPrim_L,UPrim_R,nv,t1,t2,doBC)
! MODULES
USE MOD_Flux         ,ONLY:EvalEulerFlux1D_fast
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)                                          :: Nloc      !< local polynomial degree
REAL,DIMENSION(PP_nVar    ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: U_L       !< conservative solution at left side of the interface
REAL,DIMENSION(PP_nVar    ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: U_R       !< conservative solution at right side of the interface
REAL,DIMENSION(PP_nVarPrim,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: UPrim_L   !< primitive solution at left side of the interface
REAL,DIMENSION(PP_nVarPrim,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: UPrim_R   !< primitive solution at right side of the interface
REAL,DIMENSION(3          ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: nv,t1,t2  !> normal vector and tangential vectors at side
REAL,DIMENSION(PP_nVar    ,0:Nloc,0:ZDIM(Nloc)),INTENT(OUT) :: FOut      !< advective flux
LOGICAL,INTENT(IN)                                          :: doBC      !< marker whether side is a BC side
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                 :: i,j
REAL,DIMENSION(PP_nVar) :: F_L,F_R,F
REAL,DIMENSION(PP_2Var) :: U_LL,U_RR
PROCEDURE(RiemannInt),POINTER :: Riemann_loc !< pointer defining the standard inner Riemann solver
!==================================================================================================================================
IF (doBC) THEN
  Riemann_loc => RiemannBC_pointer
ELSE
  Riemann_loc => Riemann_pointer
END IF

DO j=0,ZDIM(Nloc); DO i=0,Nloc
  ! Momentum has to be rotatet using the normal system individual for each
  ! left state: U_L
  U_LL(EXT_DENS)=U_L(DENS,i,j)
  U_LL(EXT_SRHO)=1./U_LL(EXT_DENS)
  U_LL(EXT_ENER)=U_L(ENER,i,j)
  U_LL(EXT_PRES)=UPrim_L(PRES,i,j)


  ! rotate velocity in normal and tangential direction
  U_LL(EXT_VEL1)=DOT_PRODUCT(UPrim_L(VELV,i,j),nv(:,i,j))
  U_LL(EXT_VEL2)=DOT_PRODUCT(UPrim_L(VELV,i,j),t1(:,i,j))
  U_LL(EXT_MOM1)=U_LL(EXT_DENS)*U_LL(EXT_VEL1)
  U_LL(EXT_MOM2)=U_LL(EXT_DENS)*U_LL(EXT_VEL2)
#if PP_dim==3
  U_LL(EXT_VEL3)=DOT_PRODUCT(UPrim_L(VELV,i,j),t2(:,i,j))
  U_LL(EXT_MOM3)=U_LL(EXT_DENS)*U_LL(EXT_VEL3)
#else
  U_LL(EXT_VEL3)=0.
  U_LL(EXT_MOM3)=0.
#endif
  ! right state: U_R
  U_RR(EXT_DENS)=U_R(DENS,i,j)
  U_RR(EXT_SRHO)=1./U_RR(EXT_DENS)
  U_RR(EXT_ENER)=U_R(ENER,i,j)
  U_RR(EXT_PRES)=UPrim_R(PRES,i,j)
  ! rotate momentum in normal and tangential direction
  U_RR(EXT_VEL1)=DOT_PRODUCT(UPRIM_R(VELV,i,j),nv(:,i,j))
  U_RR(EXT_VEL2)=DOT_PRODUCT(UPRIM_R(VELV,i,j),t1(:,i,j))
  U_RR(EXT_MOM1)=U_RR(EXT_DENS)*U_RR(EXT_VEL1)
  U_RR(EXT_MOM2)=U_RR(EXT_DENS)*U_RR(EXT_VEL2)
#if PP_dim==3
  U_RR(EXT_VEL3)=DOT_PRODUCT(UPRIM_R(VELV,i,j),t2(:,i,j))
  U_RR(EXT_MOM3)=U_RR(EXT_DENS)*U_RR(EXT_VEL3)
#else
  U_RR(EXT_VEL3)=0.
  U_RR(EXT_MOM3)=0.
#endif

#ifndef SPLIT_DG
  CALL EvalEulerFlux1D_fast(U_LL,F_L)
  CALL EvalEulerFlux1D_fast(U_RR,F_R)
#endif /*SPLIT_DG*/

  CALL Riemann_loc(F_L,F_R,U_LL,U_RR,F)

  ! Back Rotate the normal flux into Cartesian direction
  Fout(DENS,i,j)=F(DENS)
  Fout(MOMV,i,j)=nv(:,i,j)*F(MOM1)  &
               + t1(:,i,j)*F(MOM2)  &
#if PP_dim==3
               + t2(:,i,j)*F(MOM3)
#else
               + 0.
#endif
  Fout(ENER,i,j)=F(ENER)
END DO; END DO
END SUBROUTINE Riemann_Side

!==================================================================================================================================
!> Computes the numerical flux
!> Conservative States are rotated into normal direction in this routine and are NOT backrotated: don't use it after this routine!!
!> Attention 2: numerical flux is backrotated at the end of the routine!!
!==================================================================================================================================
SUBROUTINE Riemann_Point(FOut,U_L,U_R,UPrim_L,UPrim_R,nv,t1,t2,doBC)
! MODULES
USE MOD_Flux         ,ONLY:EvalEulerFlux1D_fast
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
REAL,DIMENSION(PP_nVar    ),INTENT(IN)  :: U_L        !< conservative solution at left side of the interface
REAL,DIMENSION(PP_nVar    ),INTENT(IN)  :: U_R        !< conservative solution at right side of the interface
REAL,DIMENSION(PP_nVarPrim),INTENT(IN)  :: UPrim_L    !< primitive solution at left side of the interface
REAL,DIMENSION(PP_nVarPrim),INTENT(IN)  :: UPrim_R    !< primitive solution at right side of the interface
REAL,DIMENSION(3          ),INTENT(IN)  :: nv,t1,t2   !< normal vector and tangential vectors at side
REAL,DIMENSION(PP_nVar    ),INTENT(OUT) :: FOut       !< advective flux
LOGICAL,INTENT(IN)                      :: doBC       !< marker whether side is a BC side
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL,DIMENSION(PP_nVar) :: F_L,F_R,F
REAL,DIMENSION(PP_2Var) :: U_LL,U_RR
PROCEDURE(RiemannInt),POINTER :: Riemann_loc !< pointer defining the standard inner Riemann solver
!==================================================================================================================================
IF (doBC) THEN
  Riemann_loc => RiemannBC_pointer
ELSE
  Riemann_loc => Riemann_pointer
END IF

! Momentum has to be rotatet using the normal system individual for each
! left state: U_L
U_LL(EXT_DENS)=U_L(DENS)
U_LL(EXT_SRHO)=1./U_LL(EXT_DENS)
U_LL(EXT_ENER)=U_L(ENER)
U_LL(EXT_PRES)=UPrim_L(PRES)


! rotate velocity in normal and tangential direction
U_LL(EXT_VEL1)=DOT_PRODUCT(UPrim_L(VELV),nv(:))
U_LL(EXT_VEL2)=DOT_PRODUCT(UPrim_L(VELV),t1(:))
U_LL(EXT_MOM1)=U_LL(EXT_DENS)*U_LL(EXT_VEL1)
U_LL(EXT_MOM2)=U_LL(EXT_DENS)*U_LL(EXT_VEL2)
#if PP_dim==3
U_LL(EXT_VEL3)=DOT_PRODUCT(UPrim_L(VELV),t2(:))
U_LL(EXT_MOM3)=U_LL(EXT_DENS)*U_LL(EXT_VEL3)
#else
U_LL(EXT_VEL3)=0.
U_LL(EXT_MOM3)=0.
#endif
! right state: U_R
U_RR(EXT_DENS)=U_R(DENS)
U_RR(EXT_SRHO)=1./U_RR(EXT_DENS)
U_RR(EXT_ENER)=U_R(ENER)
U_RR(EXT_PRES)=UPrim_R(PRES)
! rotate momentum in normal and tangential direction
U_RR(EXT_VEL1)=DOT_PRODUCT(UPRIM_R(VELV),nv(:))
U_RR(EXT_VEL2)=DOT_PRODUCT(UPRIM_R(VELV),t1(:))
U_RR(EXT_MOM1)=U_RR(EXT_DENS)*U_RR(EXT_VEL1)
U_RR(EXT_MOM2)=U_RR(EXT_DENS)*U_RR(EXT_VEL2)
#if PP_dim==3
U_RR(EXT_VEL3)=DOT_PRODUCT(UPRIM_R(VELV),t2(:))
U_RR(EXT_MOM3)=U_RR(EXT_DENS)*U_RR(EXT_VEL3)
#else
U_RR(EXT_VEL3)=0.
U_RR(EXT_MOM3)=0.
#endif

# ifndef SPLIT_DG
CALL EvalEulerFlux1D_fast(U_LL,F_L)
CALL EvalEulerFlux1D_fast(U_RR,F_R)
#endif /*SPLIT_DG*/

CALL Riemann_loc(F_L,F_R,U_LL,U_RR,F)

! Back rotate the normal flux into Cartesian direction
Fout(DENS)=F(DENS)
Fout(MOMV)=nv(:)*F(MOM1)  &
          +t1(:)*F(MOM2)  &
#if PP_dim==3
          +t2(:)*F(MOM3)
#else
          +0.
#endif
Fout(ENER)=F(ENER)
END SUBROUTINE Riemann_Point

#if PARABOLIC
!==================================================================================================================================
!> Computes the viscous NSE diffusion fluxes in all directions to approximate the numerical flux
!> Actually not a Riemann solver, only here for coding reasons
!==================================================================================================================================
SUBROUTINE ViscousFlux_Side(Nloc,F,UPrim_L,UPrim_R, &
                            gradUx_L,gradUy_L,gradUz_L,gradUx_R,gradUy_R,gradUz_R,nv &
#if EDDYVISCOSITY
                           ,muSGS_L,muSGS_R &
#endif
                           )
! MODULES
USE MOD_Flux         ,ONLY: EvalDiffFlux3D
USE MOD_Lifting_Vars ,ONLY: diffFluxX_L,diffFluxY_L,diffFluxZ_L
USE MOD_Lifting_Vars ,ONLY: diffFluxX_R,diffFluxY_R,diffFluxZ_R
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)                                             :: Nloc     !< local polynomial degree
                                                               !> solution in primitive variables at left/right side of interface
REAL,DIMENSION(PP_nVarPrim   ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: UPrim_L,UPrim_R
                                                               !> solution gradients in x/y/z-direction left/right of interface
REAL,DIMENSION(PP_nVarLifting,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: gradUx_L,gradUx_R,gradUy_L,gradUy_R,gradUz_L,gradUz_R
REAL,DIMENSION(3             ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: nv  !< normal vector
REAL,DIMENSION(PP_nVar       ,0:Nloc,0:ZDIM(Nloc)),INTENT(OUT) :: F   !< viscous flux
#if EDDYVISCOSITY
REAL,DIMENSION(1             ,0:Nloc,0:ZDIM(Nloc)),INTENT(IN)  :: muSGS_L,muSGS_R   !> eddy viscosity left/right of the interface
#endif
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                                                       :: p,q
!==================================================================================================================================
! Don't forget the diffusion contribution, my young padawan
! Compute NSE Diffusion flux
CALL EvalDiffFlux3D(Nloc,UPrim_L,   gradUx_L,   gradUy_L,   gradUz_L  &
                                ,diffFluxX_L,diffFluxY_L,diffFluxZ_L  &
#if EDDYVISCOSITY
                   ,muSGS_L &
#endif
      )
CALL EvalDiffFlux3D(Nloc,UPrim_R,   gradUx_R,   gradUy_R,   gradUz_R  &
                                ,diffFluxX_R,diffFluxY_R,diffFluxZ_R  &
#if EDDYVISCOSITY
                   ,muSGS_R&
#endif
      )
! Arithmetic mean of the fluxes
DO q=0,ZDIM(Nloc); DO p=0,Nloc
  F(:,p,q)=0.5*(nv(1,p,q)*(diffFluxX_L(:,p,q)+diffFluxX_R(:,p,q)) &
               +nv(2,p,q)*(diffFluxY_L(:,p,q)+diffFluxY_R(:,p,q)) &
               +nv(3,p,q)*(diffFluxZ_L(:,p,q)+diffFluxZ_R(:,p,q)))
END DO; END DO
END SUBROUTINE ViscousFlux_Side

!==================================================================================================================================
!> Computes the viscous NSE diffusion fluxes in all directions to approximate the numerical flux
!> Actually not a Riemann solver, only here for coding reasons
!==================================================================================================================================
SUBROUTINE ViscousFlux_Point(F,UPrim_L,UPrim_R, &
                             gradUx_L,gradUy_L,gradUz_L,gradUx_R,gradUy_R,gradUz_R,nv &
#if EDDYVISCOSITY
                            ,muSGS_L,muSGS_R &
#endif
                            )
! MODULES
USE MOD_Flux         ,ONLY: EvalDiffFlux3D
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
                                           !> solution in primitive variables at left/right side of the interface
REAL,DIMENSION(PP_nVarPrim   ),INTENT(IN)  :: UPrim_L,UPrim_R
                                           !> solution gradients in x/y/z-direction left/right of the interface
REAL,DIMENSION(PP_nVarLifting),INTENT(IN)  :: gradUx_L,gradUx_R,gradUy_L,gradUy_R,gradUz_L,gradUz_R
REAL,DIMENSION(3             ),INTENT(IN)  :: nv  !< normal vector
REAL,DIMENSION(PP_nVar       ),INTENT(OUT) :: F   !< viscous flux
#if EDDYVISCOSITY
REAL,INTENT(IN)                            :: muSGS_L,muSGS_R    !> eddy viscosity left/right of the interface
#endif
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL,DIMENSION(PP_nVar)  :: diffFluxX_L,diffFluxY_L,diffFluxZ_L
REAL,DIMENSION(PP_nVar)  :: diffFluxX_R,diffFluxY_R,diffFluxZ_R
!==================================================================================================================================
! Don't forget the diffusion contribution, my young padawan
! Compute NSE Diffusion flux
CALL EvalDiffFlux3D(UPrim_L,   gradUx_L,   gradUy_L,   gradUz_L  &
                           ,diffFluxX_L,diffFluxY_L,diffFluxZ_L  &
#if EDDYVISCOSITY
                   ,muSGS_L &
#endif
      )
CALL EvalDiffFlux3D(UPrim_R,   gradUx_R,   gradUy_R,   gradUz_R  &
                           ,diffFluxX_R,diffFluxY_R,diffFluxZ_R  &
#if EDDYVISCOSITY
                   ,muSGS_R&
#endif
      )
! Arithmetic mean of the fluxes
F(:)=0.5*(nv(1)*(diffFluxX_L(:)+diffFluxX_R(:)) &
         +nv(2)*(diffFluxY_L(:)+diffFluxY_R(:)) &
         +nv(3)*(diffFluxZ_L(:)+diffFluxZ_R(:)))
END SUBROUTINE ViscousFlux_Point
#endif /* PARABOLIC */

!==================================================================================================================================
!> Local Lax-Friedrichs (Rusanov) Riemann solver
!==================================================================================================================================
PPURE SUBROUTINE Riemann_LF(F_L,F_R,U_LL,U_RR,F)
! MODULES
USE MOD_EOS_Vars      ,ONLY: Kappa
#ifdef SPLIT_DG
USE MOD_SplitFlux     ,ONLY: SplitDGSurface_pointer
#endif /*SPLIT_DG*/
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
                                                !> extended solution vector on the left/right side of the interface
REAL,DIMENSION(PP_2Var),INTENT(IN) :: U_LL,U_RR
                                                !> advection fluxes on the left/right side of the interface
REAL,DIMENSION(PP_nVar),INTENT(IN) :: F_L,F_R
REAL,DIMENSION(PP_nVar),INTENT(OUT):: F         !< resulting Riemann flux
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL    :: LambdaMax
!==================================================================================================================================
! Lax-Friedrichs
LambdaMax = MAX( ABS(U_RR(EXT_VEL1)),ABS(U_LL(EXT_VEL1)) ) + MAX( SPEEDOFSOUND_HE(U_LL),SPEEDOFSOUND_HE(U_RR) )
#ifndef SPLIT_DG
F = 0.5*((F_L+F_R) - LambdaMax*(U_RR(CONS) - U_LL(CONS)))
#else
! get split flux
CALL SplitDGSurface_pointer(U_LL,U_RR,F)
! compute surface flux
F = F - 0.5*LambdaMax*(U_RR(CONS) - U_LL(CONS))
#endif /*SPLIT_DG*/
END SUBROUTINE Riemann_LF

!=================================================================================================================================
!> Harten-Lax-Van-Leer Riemann solver resolving contact discontinuity
!=================================================================================================================================
PPURE SUBROUTINE Riemann_HLLC(F_L,F_R,U_LL,U_RR,F)
! MODULES
USE MOD_EOS_Vars      ,ONLY: KappaM1!,kappa
IMPLICIT NONE
!---------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
                                           !> extended solution vector on the left/right side of the interface
REAL,DIMENSION(PP_2Var),INTENT(IN) :: U_LL,U_RR
                                           !> advection fluxes on the left/right side of the interface
REAL,DIMENSION(PP_nVar),INTENT(IN) :: F_L,F_R
REAL,DIMENSION(PP_nVar),INTENT(OUT):: F    !< resulting Riemann flux
!---------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL    :: H_L,H_R
REAL    :: SqrtRho_L,SqrtRho_R,sSqrtRho
REAL    :: RoeVel(3),RoeH,Roec,absVel
REAL    :: Ssl,Ssr,SStar
REAL    :: U_Star(PP_nVar),EStar
REAL    :: sMu_L,sMu_R
!REAL    :: c_L,c_R
!=================================================================================================================================
! HLLC flux

! Version A: Basic Davis estimate for wave speed
!Ssl = U_LL(EXT_VEL1) - SPEEDOFSOUND_HE(U_LL)
!Ssr = U_RR(EXT_VEL1) + SPEEDOFSOUND_HE(U_RR)

! Version B: Basic Davis estimate for wave speed
!c_L = SPEEDOFSOUND_HE(U_LL)
!c_R = SPEEDOFSOUND_HE(U_RR)
!Ssl = MIN(U_LL(EXT_VEL1) - c_L,U_RR(EXT_VEL1) - c_R)
!Ssr = MAX(U_LL(EXT_VEL1) + c_L,U_RR(EXT_VEL1) + c_R)

! Version C: Better Roe estimate for wave speeds Davis, Einfeldt
H_L       = TOTALENTHALPY_HE(U_LL)
H_R       = TOTALENTHALPY_HE(U_RR)
SqrtRho_L = SQRT(U_LL(EXT_DENS))
SqrtRho_R = SQRT(U_RR(EXT_DENS))
sSqrtRho  = 1./(SqrtRho_L+SqrtRho_R)
! Roe mean values
RoeVel    = (SqrtRho_R*U_RR(EXT_VELV) + SqrtRho_L*U_LL(EXT_VELV)) * sSqrtRho
RoeH      = (SqrtRho_R*H_R            + SqrtRho_L*H_L       )     * sSqrtRho
absVel    = DOT_PRODUCT(RoeVel,RoeVel)
Roec      = SQRT(KappaM1*(RoeH-0.5*absVel))
Ssl       = RoeVel(1) - Roec
Ssr       = RoeVel(1) + Roec

! positive supersonic speed
IF(Ssl .GE. 0.)THEN
  F=F_L
! negative supersonic speed
ELSEIF(Ssr .LE. 0.)THEN
  F=F_R
! subsonic case
ELSE
  sMu_L = Ssl - U_LL(EXT_VEL1)
  sMu_R = Ssr - U_RR(EXT_VEL1)
  SStar = (U_RR(EXT_PRES) - U_LL(EXT_PRES) + U_LL(EXT_MOM1)*sMu_L - U_RR(EXT_MOM1)*sMu_R) / (U_LL(EXT_DENS)*sMu_L - U_RR(EXT_DENS)*sMu_R)
  IF ((Ssl .LE. 0.).AND.(SStar .GE. 0.)) THEN
    EStar  = TOTALENERGY_HE(U_LL) + (SStar-U_LL(EXT_VEL1))*(SStar + U_LL(EXT_PRES)*U_LL(EXT_SRHO)/sMu_L)
    U_Star = U_LL(EXT_DENS) * sMu_L/(Ssl-SStar) * (/ 1., SStar, U_LL(EXT_VEL2:EXT_VEL3), EStar, U_LL(EXT_TKE), U_LL(EXT_OMG) /)
    F=F_L+Ssl*(U_Star-U_LL(CONS))
  ELSE
    EStar  = TOTALENERGY_HE(U_RR) + (SStar-U_RR(EXT_VEL1))*(SStar + U_RR(EXT_PRES)*U_RR(EXT_SRHO)/sMu_R)
    U_Star = U_RR(EXT_DENS) * sMu_R/(Ssr-SStar) * (/ 1., SStar, U_RR(EXT_VEL2:EXT_VEL3), EStar, U_RR(EXT_TKE), U_RR(EXT_OMG) /)
    F=F_R+Ssr*(U_Star-U_RR(CONS))
  END IF
END IF ! subsonic case
END SUBROUTINE Riemann_HLLC


#ifdef SPLIT_DG
!==================================================================================================================================
!> Riemann solver using purely the average fluxes
!==================================================================================================================================
PPURE SUBROUTINE Riemann_FluxAverage(F_L,F_R,U_LL,U_RR,F)
! MODULES
USE MOD_SplitFlux     ,ONLY: SplitDGSurface_pointer
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
                                                !> extended solution vector on the left/right side of the interface
REAL,DIMENSION(PP_2Var),INTENT(IN) :: U_LL,U_RR
                                                !> advection fluxes on the left/right side of the interface
REAL,DIMENSION(PP_nVar),INTENT(IN) :: F_L,F_R
REAL,DIMENSION(PP_nVar),INTENT(OUT):: F         !< resulting Riemann flux
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================
! get split flux
CALL SplitDGSurface_pointer(U_LL,U_RR,F)
END SUBROUTINE Riemann_FluxAverage

!==================================================================================================================================
!> kinetic energy preserving and entropy consistent flux according to Chandrashekar (2012)
!==================================================================================================================================
PPURE SUBROUTINE Riemann_CH(F_L,F_R,U_LL,U_RR,F)
! MODULES
USE MOD_EOS_Vars      ,ONLY: Kappa,sKappaM1
USE MOD_SplitFlux     ,ONLY: SplitDGSurface_pointer,GetLogMean
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
                                                !> extended solution vector on the left/right side of the interface
REAL,DIMENSION(PP_2Var),INTENT(IN) :: U_LL,U_RR
                                                !> advection fluxes on the left/right side of the interface
REAL,DIMENSION(PP_nVar),INTENT(IN) :: F_L,F_R
REAL,DIMENSION(PP_nVar),INTENT(OUT):: F         !< resulting Riemann flux
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                               :: LambdaMax
REAL                               :: beta_LL,beta_RR   ! auxiliary variables for the inverse Temperature
REAL                               :: rhoMean           ! auxiliary variable for the mean density
REAL                               :: uMean,vMean,wMean ! auxiliary variable for the average velocities
REAL                               :: betaLogMean       ! auxiliary variable for the logarithmic mean inverse temperature
!==================================================================================================================================
! Lax-Friedrichs
LambdaMax = MAX( ABS(U_RR(EXT_VEL1)),ABS(U_LL(EXT_VEL1)) ) + MAX( SPEEDOFSOUND_HE(U_LL),SPEEDOFSOUND_HE(U_RR) )

! average quantities
rhoMean = 0.5*(U_LL(EXT_DENS) + U_RR(EXT_DENS))
uMean   = 0.5*(U_LL(EXT_VEL1) + U_RR(EXT_VEL1))
vMean   = 0.5*(U_LL(EXT_VEL2) + U_RR(EXT_VEL2))
wMean   = 0.5*(U_LL(EXT_VEL3) + U_RR(EXT_VEL3))

! inverse temperature
beta_LL = 0.5*U_LL(EXT_DENS)/U_LL(EXT_PRES)
beta_RR = 0.5*U_RR(EXT_DENS)/U_RR(EXT_PRES)

! logarithmic mean
CALL GetLogMean(beta_LL,beta_RR,betaLogMean)

! get split flux
CALL SplitDGSurface_pointer(U_LL,U_RR,F)

!compute flux
F(DENS:MOM3) = F(DENS:MOM3) - 0.5*LambdaMax*(U_RR(EXT_DENS:EXT_MOM3)-U_LL(EXT_DENS:EXT_MOM3))
F(ENER)      = F(ENER)      - 0.5*LambdaMax*( &
         (U_RR(EXT_DENS)-U_LL(EXT_DENS))*(0.5*sKappaM1/betaLogMean +0.5*(U_RR(EXT_VEL1)*U_LL(EXT_VEL1)+U_RR(EXT_VEL2)*U_LL(EXT_VEL2)+U_RR(EXT_VEL3)*U_LL(EXT_VEL3))) &
         +rhoMean*uMean*(U_RR(EXT_VEL1)-U_LL(EXT_VEL1)) + rhoMean*vMean*(U_RR(EXT_VEL2)-U_LL(EXT_VEL2)) + rhoMean*wMean*(U_RR(EXT_VEL3)-U_LL(EXT_VEL3)) &
         +0.5*rhoMean*sKappaM1*(1./beta_RR - 1./beta_LL))

END SUBROUTINE Riemann_CH
#endif /*SPLIT_DG*/

!==================================================================================================================================
!> Finalize Riemann solver routines
!==================================================================================================================================
SUBROUTINE FinalizeRiemann()
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================
END SUBROUTINE FinalizeRiemann


END MODULE MOD_Riemann
