!=================================================================================================================================
! Copyright (c) 2010-2016  Prof. Claus-Dieter Munz
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
!> Subroutines providing exactly evaluated functions used in initialization or boundary conditions.
!==================================================================================================================================
MODULE MOD_Exactfunc
! MODULES
IMPLICIT NONE
PRIVATE
!----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------

INTERFACE DefineParametersExactFunc
  MODULE PROCEDURE DefineParametersExactFunc
END INTERFACE

INTERFACE InitExactFunc
  MODULE PROCEDURE InitExactFunc
END INTERFACE

INTERFACE ExactFunc
  MODULE PROCEDURE ExactFunc
END INTERFACE

INTERFACE CalcSource
  MODULE PROCEDURE CalcSource
END INTERFACE


PUBLIC::DefineParametersExactFunc
PUBLIC::InitExactFunc
PUBLIC::ExactFunc
PUBLIC::CalcSource
!==================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters of exact functions
!==================================================================================================================================
SUBROUTINE DefineParametersExactFunc()
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
CALL prms%SetSection("Exactfunc")
CALL prms%CreateIntFromStringOption('IniExactFunc', "Exact function to be used for computing initial solution.")
CALL addStrListEntry('IniExactFunc','testcase' ,-1)
CALL addStrListEntry('IniExactFunc','testcase' ,0)
CALL addStrListEntry('IniExactFunc','refstate' ,1)
CALL addStrListEntry('IniExactFunc','sinedens' ,2)
CALL addStrListEntry('IniExactFunc','sinedensx',21)
CALL addStrListEntry('IniExactFunc','lindens'  ,3)
CALL addStrListEntry('IniExactFunc','sinevel'  ,4)
CALL addStrListEntry('IniExactFunc','sinevelx' ,41)
CALL addStrListEntry('IniExactFunc','sinevely' ,42)
CALL addStrListEntry('IniExactFunc','sinevelz' ,43)
CALL addStrListEntry('IniExactFunc','roundjet' ,5)
CALL addStrListEntry('IniExactFunc','cylinder' ,6)
CALL addStrListEntry('IniExactFunc','shuvortex',7)
CALL addStrListEntry('IniExactFunc','couette'  ,8)
CALL addStrListEntry('IniExactFunc','cavity'   ,9)
CALL addStrListEntry('IniExactFunc','shock'    ,10)
CALL addStrListEntry('IniExactFunc','sod'      ,11)
CALL addStrListEntry('IniExactFunc','dmr'      ,13)
#if PARABOLIC
CALL addStrListEntry('IniExactFunc','blasius'  ,1338)
#endif
CALL prms%CreateRealArrayOption(    'AdvVel',       "Advection velocity (v1,v2,v3) required for exactfunction CASE(2,21,4,8)")
CALL prms%CreateRealOption(         'MachShock',    "Parameter required for CASE(10)", '1.5')
CALL prms%CreateRealOption(         'PreShockDens', "Parameter required for CASE(10)", '1.0')
CALL prms%CreateRealArrayOption(    'IniCenter',    "Shu Vortex CASE(7) (x,y,z)")
CALL prms%CreateRealArrayOption(    'IniAxis',      "Shu Vortex CASE(7) (x,y,z)")
CALL prms%CreateRealOption(         'IniAmplitude', "Shu Vortex CASE(7)", '0.2')
CALL prms%CreateRealOption(         'IniHalfwidth', "Shu Vortex CASE(7)", '0.2')
CALL prms%CreateRealOption(         'P_Parameter', "Couette-Poiseuille flow CASE(8)", '0.0')
CALL prms%CreateRealOption(         'U_Parameter', "Couette-Poiseuille flow CASE(8)", '0.01')
#if PARABOLIC
CALL prms%CreateRealOption(         'delta99_in',   "Blasius boundary layer CASE(1338)")
CALL prms%CreateRealArrayOption(    'x_in',         "Blasius boundary layer CASE(1338)")
#endif

END SUBROUTINE DefineParametersExactFunc

!==================================================================================================================================
!> Get some parameters needed for exact function
!==================================================================================================================================
SUBROUTINE InitExactFunc()
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_ExactFunc_Vars
USE MOD_Equation_Vars      ,ONLY: IniExactFunc,IniRefState

! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================
SWRITE(UNIT_stdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT EXACT FUNCTION...'

IniExactFunc = GETINTFROMSTR('IniExactFunc')
IniRefState  = GETINT('IniRefState', "-1")
! Read in boundary parameters
SELECT CASE (IniExactFunc)
CASE(2,21,3,4,41,42,43) ! synthetic test cases
  AdvVel       = GETREALARRAY('AdvVel',3)
CASE(7) ! Shu Vortex
  IniCenter    = GETREALARRAY('IniCenter',3,'(/0.,0.,0./)')
  IniAxis      = GETREALARRAY('IniAxis',3,'(/0.,0.,1./)')
  IniAmplitude = GETREAL('IniAmplitude')
  IniHalfwidth = GETREAL('IniHalfwidth')
CASE(8) ! couette-poiseuille flow
  P_Parameter  = GETREAL('P_Parameter')
  U_Parameter  = GETREAL('U_Parameter')
CASE(10) ! shock
  MachShock    = GETREAL('MachShock')
  PreShockDens = GETREAL('PreShockDens')
#if PARABOLIC
CASE(1338) ! Blasius boundary layer solution
  delta99_in      = GETREAL('delta99_in')
  x_in            = GETREALARRAY('x_in',2,'(/0.,0./)')
  BlasiusInitDone = .TRUE. ! Mark Blasius init as done so we don't read the parameters again in BC init
#endif
CASE DEFAULT
END SELECT ! IniExactFunc

#if PP_dim==2
SELECT CASE (IniExactFunc)
CASE(43) ! synthetic test cases
  CALL CollectiveStop(__STAMP__,'The selected exact function is not available in 2D!')
CASE(2,3,4,41,42) ! synthetic test cases
  IF(AdvVel(3).NE.0.) THEN
    CALL CollectiveStop(__STAMP__,'You are computing in 2D! Please set AdvVel(3) = 0!')
  END IF
END SELECT
#endif

SWRITE(UNIT_stdOut,'(A)')' INIT EXACT FUNCTION DONE!'
SWRITE(UNIT_stdOut,'(132("-"))')
END SUBROUTINE InitExactFunc

!==================================================================================================================================
!> Specifies all the initial conditions. The state in conservative variables is returned.
!> t is the actual time
!> dt is only needed to compute the time dependent boundary values for the RK scheme
!> for each function resu and the first and second time derivative resu_t and resu_tt have to be defined (is trivial for constants)
!==================================================================================================================================
SUBROUTINE ExactFunc(ExactFunction,tIn,x,resu,RefStateOpt)
! MODULES
USE MOD_Preproc        ,ONLY: PP_PI
USE MOD_Globals        ,ONLY: Abort
USE MOD_Mathtools      ,ONLY: CROSS
USE MOD_Eos_Vars       ,ONLY: Kappa,sKappaM1,KappaM1,KappaP1,R
USE MOD_Exactfunc_Vars ,ONLY: IniCenter,IniHalfwidth,IniAmplitude,IniAxis,AdvVel
USE MOD_Exactfunc_Vars ,ONLY: MachShock,PreShockDens
USE MOD_Exactfunc_Vars ,ONLY: P_Parameter,U_Parameter
USE MOD_Equation_Vars  ,ONLY: IniRefState,RefStateCons,RefStatePrim
USE MOD_Timedisc_Vars  ,ONLY: fullBoundaryOrder,CurrentStage,dt,RKb,RKc,t
USE MOD_TestCase       ,ONLY: ExactFuncTestcase
USE MOD_EOS            ,ONLY: PrimToCons,ConsToPrim
#if PARABOLIC
USE MOD_Eos_Vars       ,ONLY: mu0
USE MOD_Exactfunc_Vars ,ONLY: delta99_in,x_in
#endif
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)              :: ExactFunction          !< determines the exact function
REAL,INTENT(IN)                 :: x(3)                   !< physical coordinates
REAL,INTENT(IN)                 :: tIn                    !< solution time (Runge-Kutta stage)
REAL,INTENT(OUT)                :: Resu(PP_nVar)          !< state in conservative variables
INTEGER,INTENT(IN),OPTIONAL     :: RefStateOpt            !< refstate to be used for exact func
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                         :: RefState
REAL                            :: tEval
REAL                            :: Resu_t(PP_nVar),Resu_tt(PP_nVar),ov ! state in conservative variables
REAL                            :: Frequency,Amplitude
REAL                            :: Omega
REAL                            :: Vel(3),Cent(3),a
REAL                            :: Prim(PP_nVarPrim)
REAL                            :: r_len
REAL                            :: Ms,xs
REAL                            :: Resul(PP_nVar),Resur(PP_nVar)
REAL                            :: random
REAL                            :: du, dTemp, RT, r2       ! aux var for SHU VORTEX,isentropic vortex case 12
REAL                            :: pi_loc,phi,radius       ! needed for cylinder potential flow
REAL                            :: h,sRT,pexit,pentry   ! needed for Couette-Poiseuille
#if PARABOLIC
! needed for blasius BL
INTEGER                         :: nSteps,i
REAL                            :: eta,deta,deta2,f,fp,fpp,fppp,fbar,fpbar,fppbar,fpppbar
REAL                            :: x_eff(3),x_offset(3)
#endif
!==================================================================================================================================
tEval=MERGE(t,tIn,fullBoundaryOrder) ! prevent temporal order degradation, works only for RK3 time integration
IF (PRESENT(RefStateOpt)) THEN
  RefState = RefStateOpt
ELSE
  RefState = IniRefState
END IF

Resu   =0.
Resu_t =0.
Resu_tt=0.

! Determine the value, the first and the second time derivative
SELECT CASE (ExactFunction)
CASE DEFAULT
  CALL ExactFuncTestcase(tEval,x,Resu,Resu_t,Resu_tt)
CASE(0)
  CALL ExactFuncTestcase(tEval,x,Resu,Resu_t,Resu_tt)
CASE(1) ! constant
  Resu = RefStateCons(:,RefState)
CASE(2) ! sinus
  Frequency=0.5
  Amplitude=0.3
  Omega=2.*PP_Pi*Frequency
  ! base flow
  prim(DENS)   = 1.
  prim(VELV) = AdvVel
  prim(PRES)   = 1.
  Vel=prim(VELV)
  cent=x-Vel*tEval
  prim(DENS)=prim(DENS)*(1.+Amplitude*SIN(Omega*SUM(cent(1:3))))
  ! g(t)
  Resu(DENS)=prim(DENS) ! rho
  Resu(MOMV)=prim(DENS)*prim(VELV) ! rho*vel
  Resu(ENER)=prim(PRES)*sKappaM1+0.5*SUM(Resu(MOMV)*prim(VELV)) ! rho*e

  IF(fullBoundaryOrder)THEN
    ov=Omega*SUM(vel)
    ! g'(t)
    Resu_t(DENS)=-Amplitude*cos(Omega*SUM(cent(1:3)))*ov
    Resu_t(MOMV)=Resu_t(DENS)*prim(VELV) ! rho*vel
    Resu_t(ENER)=0.5*SUM(Resu_t(MOMV)*prim(VELV))
    ! g''(t)
    Resu_tt(DENS)=-Amplitude*sin(Omega*SUM(cent(1:3)))*ov**2.
    Resu_tt(MOMV)=Resu_tt(DENS)*prim(VELV)
    Resu_tt(ENER)=0.5*SUM(Resu_tt(MOMV)*prim(VELV))
  END IF
CASE(21) ! sinus x
  Frequency=0.5
  Amplitude=0.3
  Omega=2.*PP_Pi*Frequency
  ! base flow
  prim(DENS)   = 1.
  prim(VELV) = AdvVel
  prim(PRES)   = 1.
  Vel=prim(VELV)
  cent=x-Vel*tEval
  prim(DENS)=prim(DENS)*(1.+Amplitude*SIN(Omega*cent(1)))
  ! g(t)
  Resu(DENS)=prim(DENS) ! rho
  Resu(MOMV)=prim(DENS)*prim(VELV) ! rho*vel
  Resu(ENER)=prim(PRES)*sKappaM1+0.5*SUM(Resu(MOMV)*prim(VELV)) ! rho*e

  IF(fullBoundaryOrder)THEN
    ov=Omega*SUM(vel)
    ! g'(t)
    Resu_t(DENS)=-Amplitude*cos(Omega*cent(1))*ov
    Resu_t(MOMV)=Resu_t(DENS)*prim(VELV) ! rho*vel
    Resu_t(ENER)=0.5*SUM(Resu_t(MOMV)*prim(VELV))
    ! g''(t)
    Resu_tt(DENS)=-Amplitude*sin(Omega*cent(1))*ov**2.
    Resu_tt(MOMV)=Resu_tt(DENS)*prim(VELV)
    Resu_tt(ENER)=0.5*SUM(Resu_tt(MOMV)*prim(VELV))
  END IF
CASE(3) ! linear in rho
  ! base flow
  prim(DENS)   = 100.
  prim(VELV)   = AdvVel
  prim(PRES)   = 1.
  Vel=prim(VELV)
  cent=x-Vel*tEval
  prim(DENS)=prim(DENS)+SUM(AdvVel*cent)
  ! g(t)
  Resu(DENS)=prim(DENS) ! rho
  Resu(MOMV)=prim(DENS)*prim(VELV) ! rho*vel
  Resu(ENER)=prim(PRES)*sKappaM1+0.5*SUM(Resu(MOMV)*prim(VELV)) ! rho*e
  IF(fullBoundaryOrder)THEN
    ! g'(t)
    Resu_t(DENS)=-SUM(Vel)
    Resu_t(MOMV)=Resu_t(DENS)*prim(VELV) ! rho*vel
    Resu_t(ENER)=0.5*SUM(Resu_t(MOMV)*prim(VELV))
  END IF
CASE(4) ! oblique sine wave (in x,y,z for 3D calculations, and x,y for 2D)
  Frequency=1.
  Amplitude=0.1
  Omega=PP_Pi*Frequency
  a=AdvVel(1)*2.*PP_Pi

  ! g(t)
#if (PP_dim == 3)
  Resu(DENS:MOM3) = 2.+ Amplitude*sin(Omega*SUM(x(1:PP_dim)) - a*tEval)
#else
  Resu(DENS:MOM2) = 2.+ Amplitude*sin(Omega*SUM(x(1:PP_dim)) - a*tEval)
  Resu(MOM3)   = 0.
#endif
  Resu(ENER)=Resu(DENS)*Resu(DENS)
  IF(fullBoundaryOrder)THEN
    ! g'(t)
#if (PP_dim == 3)
    Resu_t(DENS:MOM3)=(-a)*Amplitude*cos(Omega*SUM(x(1:PP_dim)) - a*tEval)
#else
    Resu_t(DENS:MOM2)=(-a)*Amplitude*cos(Omega*SUM(x(1:PP_dim)) - a*tEval)
    Resu_t(MOM3)=0.
#endif
    Resu_t(ENER)=2.*Resu(DENS)*Resu_t(DENS)
    ! g''(t)
#if (PP_dim == 3)
    Resu_tt(DENS:MOM3)=-a*a*Amplitude*sin(Omega*SUM(x(1:PP_dim)) - a*tEval)
#else
    Resu_tt(DENS:MOM2)=-a*a*Amplitude*sin(Omega*SUM(x(1:PP_dim)) - a*tEval)
    Resu_tt(MOM3)=0.
#endif
    Resu_tt(ENER)=2.*(Resu_t(DENS)*Resu_t(DENS) + Resu(DENS)*Resu_tt(DENS))
  END IF

CASE(41) ! SINUS in x
  Frequency=1.
  Amplitude=0.1
  Omega=PP_Pi*Frequency
  a=AdvVel(1)*2.*PP_Pi
  ! g(t)
  Resu = 0.
  Resu(DENS:MOM1)=2.+ Amplitude*sin(Omega*x(1) - a*tEval)
  Resu(ENER)=Resu(DENS)*Resu(DENS)
  IF(fullBoundaryOrder)THEN
    Resu_t = 0.
    Resu_tt = 0.
    ! g'(t)
    Resu_t(DENS:MOM1)=(-a)*Amplitude*cos(Omega*x(1) - a*tEval)
    Resu_t(ENER)=2.*Resu(1)*Resu_t(1)
    ! g''(t)
    Resu_tt(DENS:MOM1)=-a*a*Amplitude*sin(Omega*x(1) - a*tEval)
    Resu_tt(ENER)=2.*(Resu_t(DENS)*Resu_t(DENS) + Resu(DENS)*Resu_tt(DENS))
  END IF
CASE(42) ! SINUS in y
  Frequency=1.
  Amplitude=0.1
  Omega=PP_Pi*Frequency
  a=AdvVel(2)*2.*PP_Pi
  ! g(t)
  Resu = 0.
  Resu(DENS)=2.+ Amplitude*sin(Omega*x(2) - a*tEval)
  Resu(MOM2)=Resu(DENS)
  Resu(ENER)=Resu(DENS)*Resu(DENS)
  IF(fullBoundaryOrder)THEN
    Resu_tt = 0.
    ! g'(t)
    Resu_t(DENS)=(-a)*Amplitude*cos(Omega*x(2) - a*tEval)
    Resu_t(MOM2)=Resu_t(DENS)
    Resu_t(ENER)=2.*Resu(DENS)*Resu_t(DENS)
    ! g''(t)
    Resu_tt(DENS)=-a*a*Amplitude*sin(Omega*x(2) - a*tEval)
    Resu_tt(MOM2)=Resu_tt(DENS)
    Resu_tt(ENER)=2.*(Resu_t(DENS)*Resu_t(DENS) + Resu(DENS)*Resu_tt(DENS))
  END IF
#if PP_dim==3
CASE(43) ! SINUS in z
  Frequency=1.
  Amplitude=0.1
  Omega=PP_Pi*Frequency
  a=AdvVel(3)*2.*PP_Pi
  ! g(t)
  Resu = 0.
  Resu(DENS)=2.+ Amplitude*sin(Omega*x(3) - a*tEval)
  Resu(MOM3)=Resu(DENS)
  Resu(ENER)=Resu(DENS)*Resu(DENS)
  IF(fullBoundaryOrder)THEN
    Resu_tt = 0.
    ! g'(t)
    Resu_t(DENS)=(-a)*Amplitude*cos(Omega*x(3) - a*tEval)
    Resu_t(MOM3)=Resu_t(DENS)
    Resu_t(ENER)=2.*Resu(DENS)*Resu_t(DENS)
    ! g''(t)
    Resu_tt(DENS)=-a*a*Amplitude*sin(Omega*x(3) - a*tEval)
    Resu_tt(MOM3)=Resu_tt(DENS)
    Resu_tt(ENER)=2.*(Resu_t(DENS)*Resu_t(DENS) + Resu(DENS)*Resu_tt(DENS))
  END IF
#endif
CASE(5) !Roundjet Bogey Bailly 2002, Re=65000, x-axis is jet axis
  prim(DENS)  =1.
  prim(VELV)  =0.
  prim(PRES)  =1./Kappa
  prim(TEMP)  = prim(PRES)/(prim(DENS)*R)
  ! Jet inflow (from x=0, diameter 2.0)
  ! Initial jet radius: rj=1.
  ! Momentum thickness: delta_theta0=0.05=1/20
  ! Re=65000
  ! Uco=0.
  ! Uj=0.9
  r_len=SQRT((x(2)*x(2)+x(3)*x(3)))
  prim(VEL1)=0.9*0.5*(1.+TANH((1.-r_len)*10.))
  CALL RANDOM_NUMBER(random)
  ! Random disturbance +-5%
  random=0.05*2.*(random-0.5)
  prim(VEL1)=prim(VEL1)+random*prim(VEL1)
  prim(VEL2)=x(2)/r_len*0.5*random*prim(VEL1)
  prim(VEL3)=x(3)/r_len*0.5*random*prim(VEL1)
  CALL PrimToCons(prim,ResuL)
  prim(VELV)  =0.
  CALL PrimToCons(prim,ResuR)
!   after x=10 blend to ResuR
  Resu=ResuL+(ResuR-ResuL)*0.5*(1.+tanh(x(1)-10.))
CASE(6)  ! Cylinder flow
  IF(tEval .EQ. 0.)THEN   ! Initialize potential flow
    prim(DENS)=RefStatePrim(DENS,RefState)  ! Density
    prim(VEL3)=0.                           ! VelocityZ=0. (2D flow)
    ! Calculate cylinder coordinates (0<phi<Pi/2)
    pi_loc=ASIN(1.)*2.
    IF(x(1) .LT. 0.)THEN
      phi=ATAN(ABS(x(2))/ABS(x(1)))
      IF(x(2) .LT. 0.)THEN
        phi=pi_loc+phi
      ELSE
        phi=pi_loc-phi
      END IF
    ELSEIF(x(1) .GT. 0.)THEN
      phi=ATAN(ABS(x(2))/ABS(x(1)))
      IF(x(2) .LT. 0.) phi=2.*pi_loc-phi
    ELSE
      IF(x(2) .LT. 0.)THEN
        phi=pi_loc*1.5
      ELSE
        phi=pi_loc*0.5
      END IF
    END IF
    ! Calculate radius**2
    radius=x(1)*x(1)+x(2)*x(2)
    ! Calculate velocities, radius of cylinder=0.5
    prim(VEL1)=RefStatePrim(VEL1,RefState)*(COS(phi)**2*(1.-0.25/radius)+SIN(phi)**2*(1.+0.25/radius))
    prim(VEL2)=RefStatePrim(VEL1,RefState)*(-2.)*SIN(phi)*COS(phi)*0.25/radius
    ! Calculate pressure, RefState(2)=u_infinity
    prim(PRES)=RefStatePrim(PRES,RefState) + &
            0.5*prim(DENS)*(RefStatePrim(VEL1,RefState)*RefStatePrim(VEL1,RefState)-prim(VEL1)*prim(VEL1)-prim(VEL2)*prim(VEL2))
    prim(TEMP) = prim(PRES)/(prim(DENS)*R)
  ELSE  ! Use RefState as BC
    prim=RefStatePrim(:,RefState)
  END IF  ! t=0
  CALL PrimToCons(prim,resu)
CASE(7) ! SHU VORTEX,isentropic vortex
  ! base flow
  prim=RefStatePrim(:,RefState)  ! Density
  ! ini-Parameter of the Example
  vel=prim(VELV)
  RT=prim(PRES)/prim(DENS) !ideal gas
  cent=(iniCenter+vel*tEval)    !centerpoint time dependant
  cent=x-cent                   ! distance to centerpoint
  cent=CROSS(iniAxis,cent)      !distance to axis, tangent vector, length r
  cent=cent/iniHalfWidth        !Halfwidth is dimension 1
  r2=SUM(cent*cent) !
  du = iniAmplitude/(2.*PP_Pi)*exp(0.5*(1.-r2))   ! vel. perturbation
  dTemp = -kappaM1/(2.*kappa*RT)*du**2            ! adiabatic
  prim(DENS)=prim(DENS)*(1.+dTemp)**(1.*skappaM1) !rho
  prim(VELV)=prim(VELV)+du*cent(:)                !v
#if PP_dim == 2
  prim(VEL3)=0.
#endif
  prim(PRES) = prim(PRES)*(1.+dTemp)**(kappa/kappaM1) !p
  prim(TEMP) = prim(PRES)/(prim(DENS)*R)
  CALL PrimToCons(prim,resu)
CASE(8) !Couette-Poiseuille flow between plates: exact steady lamiar solution with height=1 !
        !(Gao, hesthaven, Warburton)
  RT=1. ! Hesthaven: Absorbing layers for weakly compressible flows
  sRT=1./RT
  ! size of domain must be [-0.5, 0.5]^2 -> (x*y)
  h=0.5
  prim(VEL1)     = U_parameter*(0.5*(1.+x(2)/h) + P_parameter*(1-(x(2)/h)**2))
  prim(VEL2:VEL3)= 0.
  pexit=0.9996
  pentry=1.0004
  prim(PRES)= ( ( x(1) - (-0.5) )*( pexit - pentry) / ( 0.5 - (-0.5)) ) + pentry
  prim(DENS)=prim(PRES)*sRT
  prim(TEMP)=prim(PRES)/(prim(DENS)*R)
  CALL PrimToCons(prim,Resu)
CASE(9) !lid driven cavity flow from Gao, Hesthaven, Warburton
        !"Absorbing layers for weakly compressible flows", to appear, JSC, 2016
        ! Special "regularized" driven cavity BC to prevent singularities at corners
        ! top BC assumed to be in x-direction from 0..1
  Prim = RefStatePrim(:,RefState)
  IF (x(1).LT.0.2) THEN
    prim(VEL1)=1000*4.9333*x(1)**4-1.4267*1000*x(1)**3+0.1297*1000*x(1)**2-0.0033*1000*x(1)
  ELSEIF (x(1).LE.0.8) THEN
    prim(VEL1)=1.0
  ELSE
    prim(VEL1)=1000*4.9333*x(1)**4-1.8307*10000*x(1)**3+2.5450*10000*x(1)**2-1.5709*10000*x(1)+10000*0.3633
  ENDIF
  CALL PrimToCons(prim,Resu)
CASE(10) ! shock
  prim=0.

  ! pre-shock
  prim(DENS) = PreShockDens
  Ms         = MachShock

  prim(PRES)=prim(DENS)/Kappa
  prim(TEMP)=prim(PRES)/(prim(DENS)*R)
  CALL PrimToCons(prim,Resur)

  ! post-shock
  prim(VEL2)=prim(DENS) ! temporal storage of pre-shock density
  prim(DENS)=prim(DENS)*((KappaP1)*Ms*Ms)/(KappaM1*Ms*Ms+2.)
  prim(PRES)=prim(PRES)*(2.*Kappa*Ms*Ms-KappaM1)/(KappaP1)
  prim(TEMP)=prim(PRES)/(prim(DENS)*R)
  IF (prim(VEL1) .EQ. 0.0) THEN
    prim(VEL1)=Ms*(1.-prim(VEL2)/prim(DENS))
  ELSE
    prim(VEL1)=prim(VEL1)*prim(VEL2)/prim(DENS)
  END IF
  prim(3)=0. ! reset temporal storage
  CALL PrimToCons(prim,Resul)
  xs=5.+Ms*tEval ! 5. bei 10x10x10 Rechengebiet
  ! Tanh boundary
  Resu=-0.5*(Resul-Resur)*TANH(5.0*(x(1)-xs))+Resur+0.5*(Resul-Resur)
CASE(11) ! Sod Shock tube
  xs = 0.5
  IF (X(1).LE.xs) THEN
    Resu = RefStateCons(:,1)
  ELSE
    Resu = RefStateCons(:,2)
  END IF
CASE(12) ! Shu Osher density fluctuations shock wave interaction
  IF (x(1).LT.-4.0) THEN
    prim(DENS)      = 3.857143
    prim(VEL1)      = 2.629369
    prim(VEL2:VEL3) = 0.
    prim(PRES)      = 10.33333
  ELSE
    prim(DENS)      = 1.+0.2*SIN(5.*x(1))
    prim(VELV)      = 0.
    prim(PRES)      = 1.
  END IF
  CALL PrimToCons(prim,resu)

CASE(13) ! DoubleMachReflection (see e.g. http://www.astro.princeton.edu/~jstone/Athena/tests/dmr/dmr.html )
  IF (x(1).EQ.0.) THEN
    prim = RefStatePrim(:,1)
  ELSE IF (x(1).EQ.4.0) THEN
    prim = RefStatePrim(:,2)
  ELSE
    IF (x(1).LT.1./6.+(x(2)+20.*t)*1./3.**0.5) THEN
      prim = RefStatePrim(:,1)
    ELSE
      prim = RefStatePrim(:,2)
    END IF
  END IF
  CALL PrimToCons(prim,resu)
#if PARABOLIC
CASE(1338) ! blasius
  prim=RefStatePrim(:,RefState)
  ! calculate equivalent x for Blasius flat plate to have delta99_in at x_in
  x_offset(1)=(delta99_in/5)**2*prim(DENS)*prim(VEL1)/mu0-x_in(1)
  x_offset(2)=-x_in(2)
  x_offset(3)=0.
  x_eff=x+x_offset
  IF(x_eff(2).GT.0 .AND. x_eff(1).GT.0) THEN
    ! scale bl position in physical space to reference space, eta=5 is ~99% bl thickness
    eta=x_eff(2)*(prim(DENS)*prim(VEL1)/(mu0*x_eff(1)))**0.5

    deta=0.02 ! step size
    nSteps=CEILING(eta/deta)
    deta =eta/nSteps
    deta2=0.5*deta

    f=0.
    fp=0.
    fpp=0.332 ! default literature value, don't change if you don't know what you're doing
    fppp=0.
    !Blasius boundary layer
    DO i=1,nSteps
      ! predictor
      fbar    = f   + deta * fp
      fpbar   = fp  + deta * fpp
      fppbar  = fpp + deta * fppp
      fpppbar = -0.5*fbar*fppbar
      ! corrector
      f       = f   + deta2 * (fp   + fpbar)
      fp      = fp  + deta2 * (fpp  + fppbar)
      fpp     = fpp + deta2 * (fppp + fpppbar)
      fppp    = -0.5*f*fpp
    END DO
    prim(VEL2)=0.5*(mu0*prim(VEL1)/prim(DENS)/x_eff(1))**0.5*(fp*eta-f)
    prim(VEL1)=RefStatePrim(VEL1,RefState)*fp
  ELSE
    IF(x_eff(2).LE.0) THEN
      prim(VEL1)=0.
    END IF
  END IF
  CALL PrimToCons(prim,resu)
#endif
END SELECT ! ExactFunction
#if PP_dim==2
Resu(MOM3)=0.
#endif

! For O3 LS 3-stage RK, we have to define proper time dependent BC
IF(fullBoundaryOrder)THEN ! add resu_t, resu_tt if time dependant
#if PP_dim==2
  Resu_t=0.
  Resu_tt=0.
#endif
  SELECT CASE(CurrentStage)
  CASE(1)
    ! resu = g(t)
  CASE(2)
    ! resu = g(t) + dt/3*g'(t)
    Resu=Resu + dt*RKc(2)*Resu_t
  CASE(3)
    ! resu = g(t) + 3/4 dt g'(t) +5/16 dt^2 g''(t)
    Resu=Resu + RKc(3)*dt*Resu_t + RKc(2)*RKb(2)*dt*dt*Resu_tt
  CASE DEFAULT
    ! Stop, works only for 3 Stage O3 LS RK
    CALL Abort(__STAMP__,&
               'Exactfuntion works only for 3 Stage O3 LS RK!')
  END SELECT
END IF


END SUBROUTINE ExactFunc

!==================================================================================================================================
!> Compute source terms for some specific testcases and adds it to DG time derivative
!==================================================================================================================================
SUBROUTINE CalcSource(Ut,t)
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_EddyVisc_Vars    ,ONLY: muSGS
USE MOD_Equation_Vars    ,ONLY: IniExactFunc, sigmaK, sigmaG, Comega1, Comega2, Cmu, epsOMG, epsTKE, s23, s43
USE MOD_DG_Vars          ,ONLY: U
USE MOD_EOS              ,ONLY: ConsToPrim
#if PARABOLIC
USE MOD_Lifting_Vars     ,ONLY: gradUx,gradUy
#if PP_dim == 3
USE MOD_Lifting_Vars     ,ONLY: gradUz
#endif
USE MOD_Eos_Vars         ,ONLY: mu0
#endif
USE MOD_Mesh_Vars        ,ONLY: Elem_xGP,sJ,nElems
#if FV_ENABLED
USE MOD_ChangeBasisByDim ,ONLY: ChangeBasisVolume
USE MOD_FV_Vars          ,ONLY: FV_Vdm,FV_Elems
#endif
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
REAL,INTENT(IN)     :: t                                       !< current solution time
REAL,INTENT(INOUT)  :: Ut(PP_nVar,0:PP_N,0:PP_N,0:PP_NZ,nElems) !< DG time derivative
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: i,j,k,iElem
REAL                :: invR, invG, invK
REAL                :: ProdK, ProdG, DissK, DissG, SijSij, diffEff, crossG, dGdG, SijGradU
REAL                :: mut, muS, sRho, kPos, gPos
REAL                :: Sxx, Syy, Sxy 
#if PP_dim==3 
REAL                :: Sxz, Syz, Szz
#endif
REAL                :: Ut_src(PP_nVar,0:PP_N,0:PP_N,0:PP_NZ)
REAL                :: prim(PP_nVarPrim)
#if FV_ENABLED
REAL                :: Ut_src2(PP_nVar,0:PP_N,0:PP_N,0:PP_NZ)
#endif
INTEGER             :: FV_Elem
REAL                :: tmpVar(3), massImb
!==================================================================================================================================
! do something here to add source to k-g

#if PARABOLIC

tmpVar = 0.

DO iElem=1,nElems
#if FV_ENABLED
  FV_Elem = FV_Elems(iElem)
#else
  FV_Elem = 0
#endif

  DO k=0,PP_NZ; DO j=0,PP_N; DO i=0,PP_N

    ! start to compute the source terms
    CALL ConsToPrim(prim,U(:,i,j,k,iElem))

    sRho  = 1./prim(DENS)
    muS   = VISCOSITY_PRIM(prim)
    mut   = muSGS(1,i,j,k,iElem)

    invR  = 1.0 / MAX( 0.01 * muS, mut )

    kPos  = MAX( prim(TKE), epsTKE  )
    gPos  = MAX( prim(OMG), epsOMG )
    invK  = 1.0 / kPos
    invG  = 1.0 / gPos

    ! production of rho*TKE
#if PP_dim==2
    Sxx      = 0.5 * ( s43 * gradUx(LIFT_VEL1,i,j,k,iElem) - s23 * gradUy(LIFT_VEL2,i,j,k,iElem) )
    Syy      = 0.5 * (-s23 * gradUx(LIFT_VEL1,i,j,k,iElem) + s43 * gradUy(LIFT_VEL2,i,j,k,iElem) ) 
    Sxy      = 0.5 * (gradUy(LIFT_VEL1,i,j,k,iElem) + gradUx(LIFT_VEL2,i,j,k,iElem))
    SijSij   = Sxx**2 + Syy**2 + 2.0 * Sxy**2 
    SijGradU = Sxx * gradUx(LIFT_VEL1,i,j,k,iElem) + Sxy * gradUy(LIFT_VEL1,i,j,k,iElem) &
             + Sxy * gradUx(LIFT_VEL2,i,j,k,iElem) + Syy * gradUy(LIFT_VEL2,i,j,k,iElem) 
#else
    Sxx      = 0.5 * ( s43 * gradUx(LIFT_VEL1,i,j,k,iElem) - s23 * gradUy(LIFT_VEL2,i,j,k,iElem) - s23 * gradUz(LIFT_VEL3,i,j,k,iElem))
    Syy      = 0.5 * (-s23 * gradUx(LIFT_VEL1,i,j,k,iElem) + s43 * gradUy(LIFT_VEL2,i,j,k,iElem) - s23 * gradUz(LIFT_VEL3,i,j,k,iElem)) 
    Szz      = 0.5 * (-s23 * gradUx(LIFT_VEL1,i,j,k,iElem) - s23 * gradUy(LIFT_VEL2,i,j,k,iElem) + s43 * gradUz(LIFT_VEL3,i,j,k,iElem))
    Sxy      = 0.5 * (gradUy(LIFT_VEL1,i,j,k,iElem) + gradUx(LIFT_VEL2,i,j,k,iElem)) 
    Sxz      = 0.5 * (gradUz(LIFT_VEL1,i,j,k,iElem) + gradUx(LIFT_VEL3,i,j,k,iElem))
    Syz      = 0.5 * (gradUz(LIFT_VEL2,i,j,k,iElem) + gradUy(LIFT_VEL3,i,j,k,iElem)) 
    SijSij   = Sxx**2 + Syy**2 + Szz**2 + (Sxy**2 + Sxz**2 + Syz**2) * 2.0
    SijGradU = ( Sxx * gradUx(LIFT_VEL1,i,j,k,iElem) &
               + Sxy * gradUy(LIFT_VEL1,i,j,k,iElem) &
               + Sxz * gradUz(LIFT_VEL1,i,j,k,iElem) &
               + Sxy * gradUx(LIFT_VEL2,i,j,k,iElem) &
               + Syy * gradUy(LIFT_VEL2,i,j,k,iElem) &
               + Syz * gradUz(LIFT_VEL2,i,j,k,iElem) &
               + Sxz * gradUx(LIFT_VEL3,i,j,k,iElem) &
               + Syz * gradUy(LIFT_VEL3,i,j,k,iElem) &
               + Szz * gradUz(LIFT_VEL3,i,j,k,iElem) )
#endif
    ! dissipation of k
    DissK = -Cmu * (prim(DENS)*kPos)**2 * invR
    !DissK = -Cmu * ABS(U(RHOK,i,j,k,iElem)) * U(RHOK,i,j,k,iElem) * invR
    ! production of k, with realizability constraint
    ProdK = 2.0 * mut * SijGradU

    ! add to source term of k equation
    IF ( U(RHOK,i,j,k,iElem) .lt. 0. ) THEN
      Ut_src(RHOK,i,j,k) = ProdK
    ELSE
      Ut_src(RHOK,i,j,k) = ProdK + DissK 
    ENDIF
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!! starting assembly of omega equation !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! production of g
    !ProdG = 0.5 * Comega2 * prim(DENS) * invG
    !ProdG = 0.5 * Comega2 * ABS(U(RHOK,i,j,k,iElem) * U(RHOG,i,j,k,iElem)) * invR
    !ProdG = 0.5 * Comega2 * prim(DENS)**2 * prim(TKE) * prim(OMG) * invR
    !ProdG = 0.5 * Comega2 / Cmu * invG * prim(DENS)
    !ProdG = 0.5 * Comega2 * prim(DENS)**2 * kPos * gPos * invR
    ProdG = 0.5 * Comega2 / Cmu * invG * prim(DENS)

    ! dissipation of g
    !DissG = -0.5 * Cmu * Comega1 * U(RHOG,i,j,k,iElem)**3 * sRho**2 * SijSij
    !DissG = -0.5 * Cmu * Comega1 * prim(DENS) * prim(OMG)**3 * ProdK * invR
    !DissG = -0.5 * Cmu * Comega1 * U(RHOG,i,j,k,iElem)**3 * sRho**2 * ProdK * invR
    !DissG  = -0.5 * Comega1 * prim(OMG) * invK * ProdG 
    !DissG  = -0.5 * Cmu * Comega1 * prim(DENS) * gPos * ProdK * invR
    !DissG  = -0.5 * Cmu * Comega1 * prim(DENS) * gPos**3 * SijSij
    !DissG = -0.5 * Cmu * Comega1 * prim(DENS) * gPos**3 * ProdK * invR
    DissG = -0.5 * Cmu * Comega1 * prim(DENS) * gPos**3 * SijSij
          
    ! cross diffusion of g
    diffEff = muS + mut * sigmaG
#if PP_dim==2
    dGdG = gradUx(LIFT_OMG,i,j,k,iElem) * gradUx(LIFT_OMG,i,j,k,iElem)&
         + gradUy(LIFT_OMG,i,j,k,iElem) * gradUy(LIFT_OMG,i,j,k,iElem)
#else
    dGdG = gradUx(LIFT_OMG,i,j,k,iElem) * gradUx(LIFT_OMG,i,j,k,iElem)&
         + gradUy(LIFT_OMG,i,j,k,iElem) * gradUy(LIFT_OMG,i,j,k,iElem)&
         + gradUz(LIFT_OMG,i,j,k,iElem) * gradUz(LIFT_OMG,i,j,k,iElem)
#endif

    crossG = -3.0 * diffEff * Cmu * prim(DENS) * kPos * gPos * invR * dGdG

    IF ( U(RHOG,i,j,k,iElem) .lt. 0. ) THEN
      Ut_src(RHOG,i,j,k) = ProdG 
    ELSE
      Ut_src(RHOG,i,j,k) = ProdG + DissG + crossG
    ENDIF

  END DO ; END DO; END DO ! i,j,k

#if FV_ENABLED
  IF (FV_Elems(iElem).GT.0) THEN ! FV elem
    CALL ChangeBasisVolume(PP_nVar,PP_N,PP_N,FV_Vdm,Ut_src(:,:,:,:),Ut_src2(:,:,:,:))
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
      Ut(RHOK,i,j,k,iElem) = Ut(RHOK,i,j,k,iElem)+Ut_src2(RHOK,i,j,k)/sJ(i,j,k,iElem,FV_Elem)
      Ut(RHOG,i,j,k,iElem) = Ut(RHOG,i,j,k,iElem)+Ut_src2(RHOG,i,j,k)/sJ(i,j,k,iElem,FV_Elem)
    END DO; END DO; END DO ! i,j,k
  ELSE
#endif 
    DO k=0,PP_NZ; DO j=0,PP_N; DO i=0,PP_N
      Ut(RHOK,i,j,k,iElem) = Ut(RHOK,i,j,k,iElem)+Ut_src(RHOK,i,j,k)/sJ(i,j,k,iElem,FV_Elem)
      Ut(RHOG,i,j,k,iElem) = Ut(RHOG,i,j,k,iElem)+Ut_src(RHOG,i,j,k)/sJ(i,j,k,iElem,FV_Elem)
    END DO; END DO; END DO ! i,j,k
#if FV_ENABLED
  END IF
#endif

END DO ! element loop 
#endif /* PARABOLIC */

END SUBROUTINE CalcSource

END MODULE MOD_Exactfunc
