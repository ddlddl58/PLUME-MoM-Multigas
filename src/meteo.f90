!********************************************************************
!> \brief Meteo module
!
!> This module contains all the variables related to the atmoshpere
!> and initialize the variables at the base of the plume.
!> \date 21/03/2014
!> @author 
!> Mattia de' Michieli Vitturi
!********************************************************************

MODULE meteo_module

  USE variables, ONLY: gi   ! Grav acceleration 

  IMPLICIT NONE

  !> Temp gradient Troposphere
  REAL*8 :: gt     
  
  !> Temp gradient Stratosphere
  REAL*8 :: gs    
  
  !> Pressure at sea level
  REAL*8 :: p0     
  
  !> Temperature at sea level
  REAL*8 :: t0     
  
  !> Bottom height of the tropopause
  REAL*8 :: h1    
  
  !> Top height of the tropopause
  REAL*8 :: h2    

  !> Relative humidity for standard atmosphere
  REAL*8 :: rh
  
  !> Wind angle
  REAL*8 :: cos_theta , sin_theta

  !> Atmospheric density at sea level
  REAL*8 :: rho_atm0

  !> Horizonal wind speed
  REAL*8 :: u_atm   

  !> Atmospheric density
  REAL*8 :: rho_atm  

  !> Atmospheric specific humidity 
  REAL*8 :: sphu_atm

  !> Atmospheric kinematic viscosity
  REAL*8 :: visc_atm 

  !> Atmospheric kinematic viscosity at sea level 
  REAL*8 :: visc_atm0

  !> Atmospheric temperature
  REAL*8 :: ta      

  !> Atmospheric pressure
  REAL*8 :: pa      

  !> Vertical gradient of the pressure
  REAL*8 :: dpdz     

  !> Vertical gradient of the temperature
  REAL*8 :: dtdz     

  !> Vertical gradient of the hor. atm. vel.
  REAL*8 :: duatm_dz 

  !> perfect gas constant for dry air ( J/(kg K) )
  REAL*8 :: rair

  !> specific heat capacity for dry air
  REAL*8 :: cpair
  
  !> reference temperature (K)
  REAL*8, PARAMETER :: T_ref = 273.15D0
  
  !> enthalpy of water vapor at reference temperature (J kg-1)
  REAL*8, PARAMETER :: h_wv0 = 2.501D6
  
  !> specifc heat of water vapor (J K-1 kg-1)
  REAL*8, PARAMETER :: c_wv = 1996.D0
  
  !> enthalpy of liquid water at reference temperature (J kg-1)
  REAL*8, PARAMETER :: h_lw0 = 3.337D5
  
  !> specific heat of liquid water (J K-1 kg-1)
  REAL*8, PARAMETER :: c_lw = 4187.0D0

  !> specific heat of ice (J K-1 kg-1)
  REAL*8, PARAMETER :: c_ice = 2108.0D0
  
  !> molecular weight of dry air
  REAL*8, PARAMETER :: da_mol_wt = 0.029D0
  
  !> molecular weight of water vapor
  REAL*8, PARAMETER :: wv_mol_wt = 0.018D0
   
  !> gas constant for water vapor ( J/(kg K) )
  REAL*8, PARAMETER :: rwv = 462

  INTEGER :: n_atm_profile

  !> atmospheric profile above the vent. It is an array with n_atm_profile rows
  !> and 7 columns:\n
  !> - 1) height (km asl)
  !> - 2) density (kg/m^3)
  !> - 3) pressure (hPa)
  !> - 4) temperature (K) 
  !> - 5) specific-humidity (kg/kg)
  !> - 6) wind velocity West->East (m/s)
  !> - 7) wind velocity North-South (m/s)
  !> .
  REAL*8, ALLOCATABLE :: atm_profile(:,:)

  CHARACTER*10 :: read_atm_profile

  REAL*8 :: u_r , z_r , exp_wind

  REAL*8, ALLOCATABLE :: rho_atm_month_lat(:) , pres_atm_month_lat(:) ,   &
       temp_atm_month_lat(:) , temp_atm_month(:,:)

  REAL*8, ALLOCATABLE :: h_levels(:)
  
  REAL*8 :: wind_mult_coeff

  SAVE

CONTAINS

  !******************************************************************************
  !> \brief Meteo parameters initialization
  !
  !> This subroutine evaluate the atmosphere parameters (temperature, pressure,
  !> density and wind) at the base of the plume.
  !> \date 22/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE initialize_meteo

    IMPLICIT NONE

    CALL zmet

    rho_atm0 = rho_atm

    RETURN

  END SUBROUTINE initialize_meteo

  !******************************************************************************
  !> \brief Meteo parameters
  !
  !> This subroutine evaluate the atmosphere parameters (temperature, pressure,
  !> density and wind) at height z.
  !> \date 22/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE zmet

    USE plume_module, ONLY: z , vent_height

    USE variables, ONLY : verbose_level

    IMPLICIT NONE

    REAL*8 :: const, const1, t1, p1, p2
    REAL*8 :: const2

    !> Horizontal components of the wind
    REAL*8 :: WE_wind , NS_wind

    !> Sutherland's constant
    REAL*8 :: Cs

    ! Variables used to compute duatm_dz
    REAL*8 :: eps_z , z_eps

    REAL*8 :: WE_wind_eps , NS_wind_eps , u_atm_eps

    ! Saturation mixing ratio (hPa)
    REAL*8 :: es
    
    IF ( read_atm_profile .EQ. 'card' ) THEN

       ! interp density profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(2,:), z, rho_atm)

       ! interp pressure profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(3,:), z, pa)

       ! interp temperature profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(4,:), z, ta)

       ! interp specific humifity profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(5,:), z, sphu_atm)

       ! interp pressure profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(6,:), z, WE_wind)

       ! interp pressure profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(7,:), z, NS_wind)

       IF ( ( WE_wind .EQ. 0.D0 ) .AND. ( NS_wind .EQ. 0.D0 ) ) THEN

          WE_wind = 1.D-15
          NS_wind = 1.D-15
          
       END IF
       
       u_atm = DSQRT( WE_wind**2 + NS_wind**2 )

       cos_theta = WE_wind / u_atm
       sin_theta = NS_wind / u_atm

       eps_z = 1.D-5
       z_eps = z + eps_z

       ! interp pressure profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(6,:), z_eps,         &
            WE_wind_eps)

       ! interp pressure profile
       CALL interp_1d_scalar(atm_profile(1,:), atm_profile(7,:), z_eps,         &
            NS_wind_eps)

       u_atm_eps = DSQRT( WE_wind_eps**2 + NS_wind_eps**2 )

       duatm_dz = ( u_atm_eps - u_atm ) / eps_z 

    ELSEIF ( read_atm_profile .EQ. 'table' ) THEN

       ! interp density profile
       CALL interp_1d_scalar(h_levels(:), rho_atm_month_lat(:), z, rho_atm)

       ! interp pressure profile
       CALL interp_1d_scalar(h_levels(:), pres_atm_month_lat(:), z, pa)

       ! interp temperature profile
       CALL interp_1d_scalar(h_levels(:), temp_atm_month_lat(:), z, ta)

       IF ( ( z - vent_height ) .LE. z_r ) THEN

          u_atm = u_r * ( ( z - vent_height ) / z_r )**exp_wind

          duatm_dz =  ( exp_wind * u_r * ( ( z - vent_height ) / z_r )         &
               ** ( exp_wind - 1.D0 ) ) * ( 1.D0 / z_r )

       ELSE

          u_atm = u_r

          duatm_dz = 0.D0

       END IF
       
       cos_theta = 1.D0
       sin_theta = 0.D0


    ELSEIF ( read_atm_profile .EQ. 'standard' ) THEN

       IF ( ( z_r .LE. 0.D0 ) .OR. ( exp_wind .LE. 0.D0 ) ) THEN

          u_atm = u_r
          duatm_dz = 0.D0

       ELSE
          IF ( ( z - vent_height ) .LT. z_r ) THEN

             u_atm = u_r * ( ( z - vent_height ) / z_r )**exp_wind
             
             duatm_dz =  ( exp_wind * u_r * ( ( z - vent_height ) / z_r )       &
                  ** ( exp_wind - 1.D0 ) ) * ( 1.D0 / z_r )
             
          ELSE
             
             u_atm = u_r            
             duatm_dz = 0.D0
             
          END IF

       END IF
       
       
       cos_theta = 1.D0
       sin_theta = 0.D0

       !      
       ! ... Temperature and pressure at the tropopause bottom
       !
       const = - gi / ( rair * gt )
       t1 = t0 + gt * h1
       p1 = p0 * (t1/t0)**const
       const1 = gi / ( rair * t1 )
       p2 = p1 * DEXP( -const1 * ( h2-h1 ) )
       const2 = - gi / ( rair * gs )

       IF ( z <= h1 ) THEN

          ! ... Troposphere

          ta = t0 + gt * z
          pa = p0 * ( ta / t0 )**const
          rho_atm = pa / ( rair*ta )

       ELSE IF (z > h1 .AND. z <= h2) THEN

          ! ... Tropopause

          ta = t1
          pa = p1 * DEXP( -const1 * ( z - h1 ) )
          rho_atm = pa / ( rair * ta )

       ELSE

          ! ... Stratosphere

          ta = t0 + gt*h1 + gs*(z-h2)
          pa = p2 * (ta/t1)**const2 
          rho_atm = pa / (rair*ta)

       ENDIF

       es = DEXP( 21.4D0 - ( 5351.D0 / ta) )

       sphu_atm = MIN( 1.D0 , rh * ( 0.622D0 * es ) / ( pa / 100.D0 ) )

       !WRITE(*,*) 'z,ta,pa',z,ta,pa
       !WRITE(*,*) 'es',100.D0*es
       !WRITE(*,*) 'sphu_atm',sphu_atm
       !READ(*,*)
       
    END IF

    ! ... Air viscosity ( Armienti et al. 1988)
    Cs = 120.D0
    visc_atm = visc_atm0 * ( 288.15D0 + Cs ) / ( ta + Cs ) * ( ta / 288.15D0 )**1.5D0

    IF ( verbose_level .GE. 2 ) THEN

       WRITE(*,*) z,rho_atm,pa,ta,u_atm,cos_theta,sin_theta
       WRITE(*,*) 'visc_atm',visc_atm
       READ(*,*)

    END IF

    RETURN

  END SUBROUTINE zmet

!---------------------------------------------------------------------------
!> Scalar interpolation
!
!> This subroutine interpolate the values of the  array f1, defined on the 
!> grid points x1, at the point x2. The value are saved in f2
!> \date 13/02/2009
!> \param    x1           original grid                (\b input)
!> \param    f1           original values              (\b input)
!> \param    x2           new point                    (\b output)
!> \param    f2           interpolated value           (\b output)
!---------------------------------------------------------------------------

  SUBROUTINE interp_1d_scalar(x1, f1, x2, f2)
    IMPLICIT NONE
    
    REAL*8, INTENT(IN), DIMENSION(:) :: x1, f1
    REAL*8, INTENT(IN) :: x2
    REAL*8, INTENT(OUT) :: f2
    INTEGER :: n, n1x, t
    REAL*8 :: grad
    
    n1x = SIZE(x1)
  
    !
    ! ... locate the grid points near the topographic points
    ! ... and interpolate linearly the profile
    !
    t = 0

    DO n = 1, n1x

       IF (x1(n) <= x2) t = n

    END DO
    
    IF ( t.EQ.0 ) THEN

       f2 = f1(1)

    ELSEIF ( t.EQ.n1x ) THEN

       f2 = f1(n1x)

    ELSE
 
       grad = (f1(t+1)-f1(t))/(x1(t+1)-x1(t))
       f2 = f1(t) + (x2-x1(t)) * grad

    END IF

    RETURN
    
  END SUBROUTINE interp_1d_scalar
  
  !------------------------------------------------------------------

END MODULE meteo_module
!----------------------------------------------------------------------
