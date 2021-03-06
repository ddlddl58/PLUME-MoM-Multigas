!********************************************************************
!> \brief Input/Output module
!
!> This module contains all the input/output subroutine and the 
!> realted variables.
!> \date 28/10/2013
!> @author 
!> Mattia de' Michieli Vitturi
!********************************************************************

MODULE inpout

    USE variables

    USE plume_module, ONLY: vent_height, alpha_inp , beta_inp , particles_loss ,&
         r0 , w0 , z , log10_mfr

    USE particles_module, ONLY: n_part , n_mom , mom0 , rhop_mom , aggr_idx ,   &
         n_part_org

    USE particles_module, ONLY : solid_partial_mass_fraction , diam1 , rho1 ,   &
         diam2 , rho2 , cp_part , settling_model , distribution ,               &
         distribution_variable , solid_mass_fraction , shape_factor

    USE particles_module, ONLY : aggregation_array , aggregate_porosity ,       &
         aggregation_model
    
    USE meteo_module, ONLY: gt , gs , p0 , t0 , h1 , h2 , rh , visc_atm0 ,      &
         rair , cpair , read_atm_profile , u_r , z_r , exp_wind ,               &
         wind_mult_coeff ,rwv

    USE solver_module, ONLY: ds0

    USE mixture_module, ONLY: t_mix0 , water_mass_fraction0,                    &
         initial_neutral_density

    USE mixture_module, ONLY: n_gas , rvolcgas , cpvolcgas , rvolcgas_mix ,     &
         volcgas_mass_fraction , volcgas_mix_mass_fraction , cpvolcgas_mix ,    &
         rhovolcgas_mix , volcgas_mol_wt , rhovolcgas , volcgas_mass_fraction0, &
         rho_lw, rho_ice, added_water_temp, added_water_mass_fraction

  IMPLICIT NONE

  !> Counter for unit files
  INTEGER :: n_unit

  !> Name of input file
  CHARACTER(LEN=30) :: inp_file

  !> Name of output file for backup of input parameters
  CHARACTER(LEN=30) :: bak_file   

  !> Name of the run (used for the output and backup files)
  CHARACTER(LEN=30) :: run_name            

  !> Name of output file for backup of input parameters
  CHARACTER(LEN=30) :: col_file

  !> Name of output file for hysplit
  CHARACTER(LEN=30) :: hy_file

  !> Name of output file for hysplit volcanic gas
  CHARACTER(LEN=30) :: hy_file_volcgas

  !> Name of output file for backup of input parameters
  CHARACTER(LEN=30) :: mom_file

  !> Name of output file for the variables used by dakota
  CHARACTER(LEN=30) :: dak_file

  !> Name of output file for the inversion variables
  CHARACTER(LEN=30) :: inversion_file

  
  !> Name of output file for the parameters of the beta distribution
  CHARACTER(LEN=30) :: mat_file

  !> Name of output file for the parameters of the beta distribution
  CHARACTER(LEN=30) :: py_file

  !> Name of file for the parameters of the atmosphere
  CHARACTER(LEN=50) :: atm_file

  !> Atmosphere input unit
  INTEGER :: atm_unit


  !> Backup input unit
  INTEGER :: bak_unit

  !> Beta distribution parameters file unit
  INTEGER :: mat_unit

  !> Beta distribution parameters file unit
  INTEGER :: py_unit

  !> Input data unit
  INTEGER :: inp_unit

  !> Output values along the column data unit
  INTEGER :: col_unit

  !> hysplit data unit
  INTEGER :: hy_unit

  INTEGER :: hy_lines

  INTEGER :: read_col_unit

  INTEGER :: col_lines

  !> hysplit volcanic gas data unit

  INTEGER :: hy_unit_volcgas

  !> hysplit scratch unit
  INTEGER :: temp_unit

  !> Moments values along the column data unit
  INTEGER :: mom_unit

  !> Dakota variables data unit
  INTEGER :: dak_unit

  !> Inversion variables data unit
  INTEGER :: inversion_unit

  REAL*8 :: mfr0
  
  REAL*8, ALLOCATABLE :: mu_lognormal(:) , sigma_lognormal(:)

  REAL*8 :: month
  REAL*8 :: lat

  REAL*8 :: hy_deltaz , hy_z , hy_z_old , hy_x , hy_y , hy_x_old , hy_y_old 

  REAL*8, ALLOCATABLE :: solid_mfr(:) , solid_mfr_old(:), solid_mfr_init(:) ,   &
        solid_mfr_oldold(:)

  NAMELIST / control_parameters / run_name , verbose_level , dakota_flag ,      &
        inversion_flag , hysplit_flag , aggregation_flag, water_flag

  NAMELIST / inversion_parameters / height_obj , r_min , r_max , n_values ,     &
       w_min , w_max
  
  NAMELIST / plume_parameters / alpha_inp , beta_inp , particles_loss
  
  NAMELIST / water_parameters / rho_lw , rho_ice , added_water_temp ,           &

       added_water_mass_fraction

  NAMELIST / atm_parameters / visc_atm0 , rair , cpair , wind_mult_coeff ,      &
       read_atm_profile , settling_model , shape_factor
  
  NAMELIST / std_atm_parameters / gt , gs , p0 , t0 , h1 , h2 , rh , u_r , z_r ,&
       exp_wind
  
  NAMELIST / table_atm_parameters / month , lat , u_r , z_r , exp_wind

  NAMELIST / initial_values / r0 , w0 , log10_mfr , mfr0 , t_mix0 ,             &
       initial_neutral_density , water_mass_fraction0 , vent_height , ds0 ,     &
       n_part , n_gas , distribution , distribution_variable , n_mom

  NAMELIST / aggregation_parameters / aggregation_model , aggregation_array ,   &
       aggregate_porosity
  
  NAMELIST / hysplit_parameters / hy_deltaz , nbl_stop , n_cloud
 
  NAMELIST / mixture_parameters / diam1 , rho1 , diam2 , rho2 , cp_part ,       &
       rvolcgas , cpvolcgas , volcgas_mol_wt , volcgas_mass_fraction0
  
  NAMELIST / lognormal_parameters / solid_partial_mass_fraction ,               &
       mu_lognormal , sigma_lognormal
  

  SAVE

CONTAINS


  !*****************************************************************************
  !> \brief Initialize variables
  !
  !> This subroutine check if the input file exists and if it does not then it
  !> it initializes the input variables with default values and creates an input
  !> file.
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE initialize

    ! External procedures

    USE particles_module, ONLY: allocate_particles

    IMPLICIT NONE

    LOGICAL :: lexist


    !---------- default flags of the CONTROL_PARAMETERS namelist ---------------
    dakota_flag = .FALSE.
    hysplit_flag = .FALSE.
    inversion_flag = .FALSE.
    aggregation_flag = .FALSE.
    water_flag = .FALSE.

    !------------ default flags of the PLUME_PARAMETERS namelist ---------------
    particles_loss = .TRUE.

    !-------------- default flags of the INITIAL_VALUES namelist ---------------
    initial_neutral_density = .FALSE.
    
    !------------ default flags of the HYSPLIT_PARAMETERS namelist -------------
    nbl_stop = .TRUE.
    
    
    gi = 9.81d0               ! Gravity acceleration
    pi_g = 4.D0 * ATAN(1.D0) 

    WIND_MULT_COEFF = 1.D0

    height_obj = -1.D0

    
    R0 = -1.D0 
    W0 = -1.D0
    Log10_mfr = -1.D0
    mfr0 = -1.D0
      
    rho_lw = -1.D0
    rho_ice = -1.D0
    added_water_temp = -1.D0
    added_water_mass_fraction = -1.D0
 
    
    n_unit = 10

    inp_file = 'plume_model.inp'

    INQUIRE (FILE=inp_file,exist=lexist)

    IF (lexist .EQV. .FALSE.) THEN

       !
       !***  Initialization of variables readed in the input file (any version of the
       !***  input file)
       !

       !---------- parameters of the INERSION_PARAMETERS namelist ------------------
       height_obj = 0.D0
       r_min = 1.D0
       r_max = 500.D0
       w_min = 1.D0
       w_max = 1000.D0
       n_values = 20
       
       !---------- parameters of the PLUME_PARAMETERS namelist ---------------------
       alpha_inp = 9.0D-2
       beta_inp = 0.6D0
       particles_loss = .TRUE.

       !---------- parameters of the WATER_PARAMETERS namelist -------------------
       rho_lw = 1000.D0
       rho_ice = 920.D0
       added_water_temp = 273.D0
       added_water_mass_fraction = 0.D0

       !---------- parameters of the ATM_PARAMETERS namelist -----------------------
       VISC_ATM0 =  1.8D-5
       RAIR=  287.026
       CPAIR=  998.000000  
       WIND_MULT_COEFF = 1.D0
       READ_ATM_PROFILE = "standard" 
       SETTLING_MODEL = "textor"
       SHAPE_FACTOR = 0.43

       !---------- parameters of the STD_ATM_PARAMETERS namelist -------------------
       gt = -6.5D-3              ! Temp gradient Troposphere
       gs = 1.0D-3               ! Temp gradient Stratosphere
       p0 = 101325.D0            ! Pressure at sea level
       t0 = 288.15D0             ! Temperature at sea level
       h1 = 11.D3
       h2 = 20.D3
       u_r = 0.D0
       z_r = 0.D0
       exp_wind = 0.D0
       rh = 90.D0

       !---------- parameters of the INITIAL_VALUES namelist --------------------

       R0 = 0.D0 
       W0 = 0.D0
       Log10_mfr = -1.0
       T_MIX0 = 1273.D0
       INITIAL_NEUTRAL_DENSITY = .FALSE.
       WATER_MASS_FRACTION0 = 3.0D-2
       VENT_HEIGHT =  1500.D0
       DS0 =  5.D0
       N_PART = 1
       DISTRIBUTION = 'lognormal'
       DISTRIBUTION_VARIABLE = 'mass_fraction'
       N_MOM = 6
       n_gas = 1
       ALLOCATE ( rvolcgas(n_gas) , cpvolcgas(n_gas) , volcgas_mol_wt(n_gas) ,  &
            volcgas_mass_fraction(n_gas) , volcgas_mass_fraction0(n_gas) ,      &
            rhovolcgas(n_gas) )

       CALL allocate_particles

       !---------- parameters of the MIXTURE_PARAMETERS namelist ----------------

       DIAM1 = 8.D-6
       RHO1 = 2000.D0
       DIAM2 = 2.D-3
       RHO2 = 2600.D0
       CP_PART = 1100.D0

       rvolcgas(1) = 462.D0
       cpvolcgas(1) = 1810.0
       volcgas_mass_fraction0(1) = 1.0D-3
       volcgas_mol_wt(1) = 0.018D0

       rvolcgas_mix = volcgas_mass_fraction0(1) * rvolcgas(1)
       cpvolcgas_mix = volcgas_mass_fraction0(1) * cpvolcgas(1)

       !---------- parameters of the LOGNORMAL_PARAMETERS namelist --------------

       ALLOCATE( mu_lognormal(n_part) )
       ALLOCATE( sigma_lognormal(n_part) )

       SOLID_PARTIAL_MASS_FRACTION =  1.D0
       MU_LOGNORMAL=  2.D0
       SIGMA_LOGNORMAL=  1.6D0

       inp_unit = n_unit

       OPEN(inp_unit,FILE=inp_file,STATUS='NEW')

       WRITE(inp_unit, control_parameters )
       WRITE(inp_unit, plume_parameters )
       WRITE(inp_unit, water_parameters )
       WRITE(inp_unit, atm_parameters )
       WRITE(inp_unit, std_atm_parameters )
       WRITE(inp_unit, initial_values )
       WRITE(inp_unit, mixture_parameters )
       WRITE(inp_unit, lognormal_parameters )

       CLOSE(inp_unit)

       WRITE(*,*) 'Input file plume_model.inp not found'
       WRITE(*,*) 'A new one with default values has been created'
       STOP

    END IF

  END SUBROUTINE initialize

  !******************************************************************************
  !> \brief Read Input data 
  !
  !> This subroutine reads input data from the file plume_model.inp and writes a
  !> backup file of the input data.
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE read_inp

    ! External variables

    USE meteo_module, ONLY: rho_atm , pa , atm_profile , n_atm_profile

    USE moments_module, ONLY : n_nodes

    USE mixture_module, ONLY: water_volume_fraction0 , rgasmix ,                &
         gas_mass_fraction, water_vapor_mass_fraction ,                         &
         liquid_water_mass_fraction , gas_volume_fraction, ice_mass_fraction

    ! External procedures

    USE meteo_module, ONLY : zmet

    USE meteo_module, ONLY : h_levels

    USE meteo_module, ONLY : rho_atm_month_lat , pres_atm_month_lat ,           &
         temp_atm_month_lat

    ! USE mixture_module, ONLY : eval_wv

    USE moments_module, ONLY : beta_function , wheeler_algorithm , coefficient

    USE particles_module, ONLY: particles_density , allocate_particles ,        &
         deallocate_particles

    IMPLICIT NONE

    LOGICAL :: tend1
    CHARACTER(LEN=80) :: card

    INTEGER :: ios
    
    INTEGER :: i , k , j

    REAL*8, DIMENSION(max_n_part) :: solid_volume_fraction0
    REAL*8, ALLOCATABLE :: d_max(:) 
    REAL*8, ALLOCATABLE :: p_beta(:) , q_beta(:)

    REAL*8, ALLOCATABLE :: mu_bar(:) , sigma_bar(:)
    REAL*8, ALLOCATABLE :: diam_constant(:)
    REAL*8, ALLOCATABLE :: diam_constant_phi(:)

    REAL*8 :: solid_tot_volume_fraction0

    REAL*8 :: C0

    REAL*8, DIMENSION(max_n_part) :: rho_solid_avg

    REAL*8 :: rho_solid_tot_avg

    REAL*8 :: rhowv
    REAL*8 :: rho_gas
    REAL*8 :: rho_mix

    REAL*8 :: alfa_s

    REAL*8, ALLOCATABLE :: xi(:) , wi(:) 
    REAL*8, ALLOCATABLE :: part_dens_array(:)

    REAL*8, ALLOCATABLE :: atm_profile0(:,:)

    INTEGER :: i_part

    INTEGER*8 :: fact2

    INTEGER, ALLOCATABLE :: coeff(:,:)

    REAL*8, ALLOCATABLE :: rho_atm_month(:,:)

    REAL*8 :: rho_atm_jan(100,13)
    REAL*8 :: rho_atm_apr(100,13)
    REAL*8 :: rho_atm_jul(100,13)
    REAL*8 :: rho_atm_oct(100,13)

    REAL*8, ALLOCATABLE :: pres_atm_month(:,:)

    REAL*8 :: pres_atm_jan(100,13)
    REAL*8 :: pres_atm_apr(100,13)
    REAL*8 :: pres_atm_jul(100,13)
    REAL*8 :: pres_atm_oct(100,13)

    REAL*8, ALLOCATABLE :: temp_atm_month(:,:)

    REAL*8 :: temp_atm_jan(100,13)
    REAL*8 :: temp_atm_apr(100,13)
    REAL*8 :: temp_atm_jul(100,13)
    REAL*8 :: temp_atm_oct(100,13)

    INTEGER :: atm_level

    INTEGER :: n_atm_levels

    REAL*8 :: coeff_lat

    REAL*8 :: Rrhovolcgas_mix

    INTEGER :: io

    INTEGER :: i_gas

    INTEGER :: i_aggr
    
    NAMELIST / beta_parameters / solid_partial_mass_fraction , p_beta , q_beta ,&
         d_max

    NAMELIST / constant_parameters / solid_partial_mass_fraction ,              &
         diam_constant_phi

    
    IF ( write_flag ) THEN

        WRITE(*,*) 
        WRITE(*,*) 'PlumeMoM (by M. de'' Michieli Vitturi)'
        WRITE(*,*) 
        WRITE(*,*) '*** Starting the run ***' 
        WRITE(*,*)

    END IF

    n_unit = n_unit + 1

    inp_unit = n_unit

    inp_file = 'plume_model.inp'

    OPEN(inp_unit,FILE=inp_file,STATUS='old')


    READ(inp_unit, control_parameters,IOSTAT=io)

    IF ( io .EQ. 0 ) THEN

       n_unit = n_unit + 1
       bak_unit = n_unit
       bak_file = TRIM(run_name)//'.bak'
       
       OPEN(bak_unit,file=bak_file,status='unknown')
       WRITE(bak_unit, control_parameters)
    
       IF ( verbose_level .GE. 1 ) WRITE(*,*) 'read control_parameters: done'

    ELSE

       WRITE(*,*) 'Problem with namelist CONTROL_PARAMETERS'
       STOP
       
    END IF

    IF ( inversion_flag ) THEN

       READ(inp_unit, inversion_parameters)
       WRITE(bak_unit, inversion_parameters)

       write_flag = .FALSE.
        
    ELSE

       write_flag = .TRUE.
       
    END IF


    READ(inp_unit, plume_parameters)
    WRITE(bak_unit, plume_parameters)


    IF (water_flag) THEN

       READ(inp_unit, water_parameters,IOSTAT=io)

       IF ( io .EQ. 0 ) THEN

          IF ( added_water_mass_fraction .EQ. -1.D0 ) THEN
             
             WRITE(*,*) 'Namelist WATER_PARAMETERS'
             WRITE(*,*) 'Plase define ADDED_WATER_MASS_FRACTION'
             STOP

          ELSE

             IF ( ( added_water_mass_fraction .LT. 0.D0 ) .OR.                  &
                  ( added_water_mass_fraction .GE. 1.D0 ) ) THEN
             
                WRITE(*,*) 'Namelist WATER_PARAMETERS'
                WRITE(*,*) 'added_water_mass_fraction should be >=0 and <1'
                WRITE(*,*) 'actual value:',added_water_mass_fraction
                STOP
                
             END IF

          END IF

          IF ( added_water_temp .EQ. -1.D0 ) THEN

             WRITE(*,*) 'Namelist WATER_PARAMETERS'
             WRITE(*,*) 'Plase specify ADDED_WATER_TEMP (K)' 
             STOP
             
          END IF

        
          IF ( rho_lw .EQ. -1.D0 ) THEN

             WRITE(*,*) 'Namelist WATER_PARAMETERS'
             WRITE(*,*) 'Plase define RHO_LW (kg/m3)'
             STOP

          END IF

          IF ( rho_ice .EQ. -1.D0 ) THEN

             WRITE(*,*) 'Namelist WATER_PARAMETERS'
             WRITE(*,*) 'Plase define RHO_ICE (kg/m3)'
             STOP
             
          END IF
  
          WRITE(bak_unit, water_parameters)

       ELSE

          WRITE(*,*) 'Problem with namelist WATER_PARAMETERS'
          STOP          

       END IF

    ELSE
       
       rho_ice = 920.D0
       rho_lw = 1000.D0
       added_water_mass_fraction = 0.D0
       added_water_temp = 273.D0

    END IF


    IF ( verbose_level .GE. 1 ) WRITE(*,*) 'read plume_parameters: done'

    READ(inp_unit, atm_parameters)
    WRITE(bak_unit, atm_parameters)



    IF ( read_atm_profile .EQ. 'table' ) THEN

       n_atm_levels = 0

       READ( inp_unit, table_atm_parameters )
       WRITE( bak_unit, table_atm_parameters )

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Density_April.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       atm_read_levels_apr: DO

          atm_level = atm_level + 1
          
          READ(atm_unit,*,IOSTAT=io ) rho_atm_apr(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO atm_read_levels_apr

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Density_Jan.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       atm_read_levels_jan: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) rho_atm_jan(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO atm_read_levels_jan

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Density_July.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       atm_read_levels_jul: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) rho_atm_jul(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO atm_read_levels_jul

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Density_Oct.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       atm_read_levels_oct: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) rho_atm_oct(atm_level,1:8)

          IF ( io > 0 ) EXIT

          n_atm_levels = atm_level

       END DO atm_read_levels_oct

       CLOSE(atm_unit)

       ! ----- READ PRESSURES -------

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Pressure_April.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       pres_read_levels_apr: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) pres_atm_apr(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO pres_read_levels_apr

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Pressure_Jan.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       pres_read_levels_jan: DO
          
          atm_level = atm_level + 1
          
          READ(atm_unit,*,IOSTAT=io) pres_atm_jan(atm_level,1:8)
          
          IF ( io > 0 ) EXIT
          
       END DO pres_read_levels_jan
       
       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Pressure_July.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       pres_read_levels_jul: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) pres_atm_jul(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO pres_read_levels_jul

       CLOSE(atm_unit)


       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Pressure_Oct.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       pres_read_levels_oct: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) pres_atm_oct(atm_level,1:8)

          IF ( io > 0 ) EXIT

          n_atm_levels = atm_level

       END DO pres_read_levels_oct

       CLOSE(atm_unit)


       ! ----- READ TEMPERATURES -------

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Temp_April.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       temp_read_levels_apr: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) temp_atm_apr(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO temp_read_levels_apr

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Temp_Jan.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       temp_read_levels_jan: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) temp_atm_jan(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO temp_read_levels_jan

       CLOSE(atm_unit)

       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Temp_July.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       temp_read_levels_jul: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) temp_atm_jul(atm_level,1:8)

          IF ( io > 0 ) EXIT

       END DO temp_read_levels_jul

       CLOSE(atm_unit)


       n_unit = n_unit + 1

       atm_unit = n_unit

       atm_file = '../AtmProfile_info/Temp_Oct.txt'

       OPEN(atm_unit,FILE=atm_file,STATUS='old')

       READ(atm_unit,*) 

       atm_level = 0

       temp_read_levels_oct: DO

          atm_level = atm_level + 1

          READ(atm_unit,*,IOSTAT=io) temp_atm_oct(atm_level,1:8)

          IF ( io > 0 ) EXIT

          n_atm_levels = atm_level

       END DO temp_read_levels_oct

       CLOSE(atm_unit)

       ALLOCATE( h_levels(n_atm_levels) )

       ALLOCATE( rho_atm_month_lat(n_atm_levels) , rho_atm_month(n_atm_levels,8) )
       ALLOCATE( pres_atm_month_lat(n_atm_levels) , pres_atm_month(n_atm_levels,8) )
       ALLOCATE( temp_atm_month_lat(n_atm_levels) , temp_atm_month(n_atm_levels,8) )

       IF ((month .GE. 0.d0) .and. (month .LE. 1.d0)) THEN
          WRITE(*,*)  'winter'
          rho_atm_month(1:n_atm_levels,1:8) = rho_atm_jan(1:n_atm_levels,1:8)
          pres_atm_month(1:n_atm_levels,1:8) = pres_atm_jan(1:n_atm_levels,1:8)
          temp_atm_month(1:n_atm_levels,1:8) = temp_atm_jan(1:n_atm_levels,1:8)
          
       ELSEIF ((month .GT. 1.d0) .and. (month .LE. 2.d0)) THEN
          WRITE(*,*)  'spring'
          rho_atm_month(1:n_atm_levels,1:8) = rho_atm_apr(1:n_atm_levels,1:8)
          pres_atm_month(1:n_atm_levels,1:8) = pres_atm_apr(1:n_atm_levels,1:8)
          temp_atm_month(1:n_atm_levels,1:8) = temp_atm_apr(1:n_atm_levels,1:8)
          
       ELSEIF ((month .GT. 2.d0) .and. (month .LE. 3.d0)) THEN
          WRITE(*,*)  'summer'
          rho_atm_month(1:n_atm_levels,1:8) = rho_atm_jul(1:n_atm_levels,1:8)
          pres_atm_month(1:n_atm_levels,1:8) = pres_atm_jul(1:n_atm_levels,1:8)
          temp_atm_month(1:n_atm_levels,1:8) = temp_atm_jul(1:n_atm_levels,1:8)
          
       ELSEIF ((month .GT. 3.d0) .and. (month .LE. 4.d0)) THEN
          WRITE(*,*)  'autumn'
          rho_atm_month(1:n_atm_levels,1:8) = rho_atm_apr(1:n_atm_levels,1:8)
          pres_atm_month(1:n_atm_levels,1:8) = pres_atm_apr(1:n_atm_levels,1:8)
          temp_atm_month(1:n_atm_levels,1:8) = temp_atm_apr(1:n_atm_levels,1:8)
          
       END IF

       IF ( ( lat .GE. 0.d0 ) .AND. ( lat .LE. 15.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 0.d0 ) / ( 15.d0 - 0.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,2) + ( 1.d0 - coeff_lat ) *         &
               rho_atm_month(1:n_atm_levels,3)

          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,2) + ( 1.d0 - coeff_lat ) *        &
               pres_atm_month(1:n_atm_levels,3)

          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,2) + ( 1.d0 - coeff_lat ) *        &
               temp_atm_month(1:n_atm_levels,3)
          
       ELSEIF ( ( lat .GT. 15.d0 ) .AND. ( lat .LE. 30.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 15.d0 ) / ( 30.d0 - 15.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,3) + ( 1.d0 - coeff_lat ) *         &
               rho_atm_month(1:n_atm_levels,4)
          
          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,3) + ( 1.d0 - coeff_lat ) *        &
               pres_atm_month(1:n_atm_levels,5)
          
          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,3) + ( 1.d0 - coeff_lat ) *        &
               temp_atm_month(1:n_atm_levels,5)
          
       ELSEIF ( ( lat .GT. 30.d0 ) .AND. ( lat .LE. 45.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 30.d0 ) / ( 45.d0 - 30.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,4) + ( 1.d0 - coeff_lat ) *         &
               rho_atm_month(1:n_atm_levels,5)
          
          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,4) + ( 1.d0 - coeff_lat ) *        &
               pres_atm_month(1:n_atm_levels,5)
          
          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,4) + ( 1.d0 - coeff_lat ) *        &
               temp_atm_month(1:n_atm_levels,5)
          
       ELSEIF ( ( lat .GT. 45.d0 ) .AND. ( lat .LE. 60.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 45.d0 ) / ( 60.d0 - 45.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,5) + ( 1.d0 - coeff_lat ) *         &
               rho_atm_month(1:n_atm_levels,6)
          
          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,5) + ( 1.d0 - coeff_lat ) *        &
               pres_atm_month(1:n_atm_levels,6)
          
          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,5) + ( 1.d0 - coeff_lat ) *        &
               temp_atm_month(1:n_atm_levels,6)
          
       ELSEIF ( ( lat .GT. 60.d0 ) .AND. ( lat .LE. 75.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 60.d0 ) / ( 75.d0 - 60.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,6) + ( 1.d0 - coeff_lat ) *         &
               rho_atm_month(1:n_atm_levels,7)
          
          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,6) + ( 1.d0 - coeff_lat ) *        &
               pres_atm_month(1:n_atm_levels,7)
          
          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,6) + ( 1.d0 - coeff_lat ) *        &
               temp_atm_month(1:n_atm_levels,7)
          
       ELSEIF ( ( lat .GT. 75.d0 ) .AND. ( lat .LE. 90.d0 ) ) THEN
          
          coeff_lat = 1.d0 - ( lat - 75.d0 ) / ( 90.d0 - 75.d0 )
          
          rho_atm_month_lat(1:n_atm_levels) = coeff_lat *                       &
               rho_atm_month(1:n_atm_levels,7)                                  &
               + ( 1.d0 - coeff_lat ) * rho_atm_month(1:n_atm_levels,8)
          
          pres_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               pres_atm_month(1:n_atm_levels,7)                                 &
               + ( 1.d0 - coeff_lat ) * pres_atm_month(1:n_atm_levels,8)
          
          temp_atm_month_lat(1:n_atm_levels) = coeff_lat *                      &
               temp_atm_month(1:n_atm_levels,7)                                 &
               + ( 1.d0 - coeff_lat ) * temp_atm_month(1:n_atm_levels,8)
          
       END IF
       
       pres_atm_month_lat(1:n_atm_levels) =                                     &
            100.d0 * pres_atm_month_lat(1:n_atm_levels)

       h_levels(1:n_atm_levels) = 1000.d0 * temp_atm_month(1:n_atm_levels,1)

    ELSEIF ( read_atm_profile .EQ. 'card' ) THEN

       tend1 = .FALSE.

       WRITE(*,*) 'search atm_profile'

       atm_profile_search: DO

          READ(inp_unit,*, END = 200 ) card

          IF( TRIM(card) == 'ATM_PROFILE' ) THEN

             EXIT atm_profile_search

          END IF

       END DO atm_profile_search

       READ(inp_unit,*) n_atm_profile

       IF ( verbose_level .GE. 1 ) WRITE(*,*) 'n_atm_profile',n_atm_profile

       ALLOCATE( atm_profile(7,n_atm_profile) )
       ALLOCATE( atm_profile0(7,n_atm_profile) )

       DO i = 1, n_atm_profile

          READ(inp_unit,*) atm_profile0(1:7,i)
          
          atm_profile(1:7,i) = atm_profile0(1:7,i)
          ! convert from km to meters
          atm_profile(1,i) = atm_profile(1,i) * 1000.D0

          ! convert from hPa to Pa
          atm_profile(3,i) = atm_profile(3,i) * 100.D0

          atm_profile(6,i) = atm_profile(6,i) * wind_mult_coeff
          atm_profile(7,i) = atm_profile(7,i) * wind_mult_coeff

          IF ( verbose_level .GE. 1 ) WRITE(*,*) i,atm_profile(1,i)

       END DO

       GOTO 210
200    tend1 = .TRUE.
210    CONTINUE

       REWIND(inp_unit)

    ELSEIF ( read_atm_profile .EQ. 'standard' ) THEN

       READ( inp_unit,std_atm_parameters )
       WRITE( bak_unit,std_atm_parameters )

    END IF

    IF ( verbose_level .GE. 1 ) WRITE(*,*) 'read atm_parameters: done'

    READ(inp_unit, initial_values)

    distribution = lower(distribution)
    distribution_variable = lower(distribution_variable)
    
    
    ALLOCATE ( rvolcgas(n_gas),cpvolcgas(n_gas),volcgas_mass_fraction(n_gas) ,  &
         volcgas_mol_wt(n_gas) , rhovolcgas(n_gas) ,                            &
         volcgas_mass_fraction0(n_gas))

    WRITE(bak_unit, initial_values)

    IF ( ( inversion_flag ) .AND. ( mfr0 .GT. 0.D0 ) ) THEN

       WRITE(*,*) 'WARNING: you should not assign mfr when inversion is true'
       WRITE(*,*) 'in the input file: mfr0',mfr0
       STOP
       
    END IF

    IF ( ( inversion_flag ) .AND. ( log10_mfr .GT. 0.D0 ) ) THEN

       WRITE(*,*) 'WARNING: you should not assign mfr when inversion is true'
       WRITE(*,*) 'in the input file: log10_mfr',log10_mfr
       STOP
       
    END IF
    
    IF ( mfr0 .GT. 0.D0 ) THEN

       IF ( log10_mfr .GT. 0.D0 ) THEN

          WRITE(*,*) 'WARNING: only one of these parameters can be assigned in'
          WRITE(*,*) 'the input file: log10_mfr,mfr0',log10_mfr,mfr0
          STOP

       ELSE

          log10_mfr = log10(mfr0)
            
          IF ( write_flag ) WRITE(*,*) 'LOG10 mass eruption rate =',log10_mfr

       END IF

    END IF
    
    IF ( ( log10_mfr .LT. 0.d0 ) .AND. ( r0 .EQ. 0.d0 ) .AND.                   &
         ( w0 .GT. 0.D0 ) ) THEN
       
       IF ( write_flag ) WRITE(*,*) 'WARNING: initial radius calculated from MER and velocity'

    END IF

    IF ( ( log10_mfr .LT. 0.d0 ) .AND. ( r0 .EQ. 0.d0 ) .AND.                   &
         ( w0 .EQ. 0.d0 ) ) THEN
       
       WRITE(*,*) 'Not enough input parameters assigned in INITIAL_VALUES'
       WRITE(*,*) 'mfr0',mfr0
       WRITE(*,*) 'log10_mfr',log10_mfr
       WRITE(*,*) 'w0',w0
       WRITE(*,*) 'r0',r0
       STOP

    END IF

    IF ( ( log10_mfr .GT. 0.d0 ) .AND. ( w0 .GT. 0.d0 )  .AND. ( r0 .GT. 0.d0 ) ) THEN

       WRITE(*,*) 'ERROR: too many input parameters: input log10_mfr or w0 and r0'
       STOP

    END IF

    IF ( distribution .EQ. 'constant' ) THEN

       n_mom = 2
       n_nodes = 1

    ELSE

       IF ( MOD(n_mom,2) == 0 ) THEN
       
          n_nodes = NINT(0.5D0 * n_mom)

       ELSE

           WRITE(*,*) 'ERROR: number of moments should be even. n_mom =',n_mom
           STOP

       END IF
          
    END IF
 
    !IF ( hysplit_flag ) THEN

    !   IF (  distribution .NE. 'constant' ) THEN

    !      WRITE(*,*) 'hysplit run requires constant distribution'
    !      STOP
          
    !   ELSE
          
    !      READ(inp_unit, hysplit_parameters)
    !      WRITE(bak_unit, hysplit_parameters)
          
    !      ALLOCATE( solid_mfr(n_part) , solid_mfr_old(n_part) )
          
    !      hy_z = vent_height + hy_deltaz
    !      hy_z_old = vent_height
    !      hy_x_old = 0.D0
    !      hy_y_old = 0.D0
          
    !   END IF
       
    !END IF

    z = vent_height

    CALL allocate_particles

    IF ( verbose_level .GE. 1 ) WRITE(*,*) 'read initial_parameters: done'

    ! ----- AGGREGATION
    IF ( aggregation_flag ) THEN

       IF ( .not.WATER_FLAG ) THEN

          WRITE(*,*) ''
          WRITE(*,*) 'ERROR: only wet aggregation is possible'
          WRITE(*,*) 'WATER FLAG =',WATER_FLAG
          
          STOP

       END IF

       n_part_org = n_part

       READ(inp_unit, aggregation_parameters,IOSTAT=ios)

       IF ( ios .NE. 0 ) THEN
          
          WRITE(*,*) 'IOSTAT=',ios
          WRITE(*,*) 'ERROR: problem with namelist AGGREGATION_PARAMETERS'
          WRITE(*,*) 'Please check the input file'
          STOP
          
       ELSE
          
          REWIND(inp_unit)
          
       END IF
       
       ! WRITE(*,*) 'QUI'
       n_part = n_part + COUNT(aggregation_array(1:n_part_org))

       ! WRITE(*,*) 'n_part_org',n_part_org
       ! WRITE(*,*) 'aggr_org',COUNT(aggregation_array(1:n_part_org))
       ! WRITE(*,*) 'n_part',n_part

       CALL deallocate_particles

       CALL allocate_particles

       aggregation_array(1:n_part) = .FALSE.
       READ(inp_unit, aggregation_parameters)

       aggregation_model = lower(aggregation_model)

       WRITE(bak_unit, aggregation_parameters)

       
       ! WRITE(*,*) size(aggregation_array)
       ! WRITE(*,*) 'aggr_org',COUNT(aggregation_array(1:n_part))
                  
       aggregation_array(n_part_org+1:n_part ) = .TRUE.

       ! WRITE(*,*) 'aggr_tot',COUNT(aggregation_array(1:n_part))

    ELSE

       aggregation_array(1:n_part) = .FALSE.
       
       n_part_org = n_part
       
    END IF

    IF ( hysplit_flag ) THEN

       IF (  distribution .NE. 'constant' ) THEN

          WRITE(*,*) 'hysplit run requires constant distribution'
          STOP
          
       ELSE
          
          READ(inp_unit, hysplit_parameters)
          WRITE(bak_unit, hysplit_parameters)
          
          ALLOCATE( solid_mfr(n_part) , solid_mfr_old(n_part) )
          
          hy_z = vent_height + hy_deltaz
          hy_z_old = vent_height
          hy_x_old = 0.D0
          hy_y_old = 0.D0
          
       END IF
       
    END IF
       
    ! ---------
    
    rvolcgas(1:n_gas) = -1.D0
    cpvolcgas(1:n_gas) = -1.D0
    volcgas_mol_wt(1:n_gas) = -1.D0
    volcgas_mass_fraction0(1:n_gas) = -1.D0
    
    READ(inp_unit, mixture_parameters) 

    IF ( ANY( rvolcgas(1:n_gas) ==-1.D0 ) ) THEN

       WRITE(*,*) 'Error in namelist MIXTURE PARAMETERS'
       WRITE(*,*) 'Please check the values of rvolcgas',rvolcgas(1:n_gas)
       STOP
       
    END IF

    IF ( ANY( cpvolcgas(1:n_gas) ==-1.D0 ) ) THEN

       WRITE(*,*) 'Error in namelist MIXTURE PARAMETERS'
       WRITE(*,*) 'Please check the values of cpvolcgas',cpvolcgas(1:n_gas)
       STOP
       
    END IF

    IF ( ANY( volcgas_mol_wt(1:n_gas) ==-1.D0 ) ) THEN

       WRITE(*,*) 'Error in namelist MIXTURE PARAMETERS'
       WRITE(*,*) 'Please check the values of rvolcgas',volcgas_mol_wt(1:n_gas)
       STOP
       
    END IF

    IF ( ANY( volcgas_mass_fraction0(1:n_gas) ==-1.D0 ) ) THEN

       WRITE(*,*) 'Error in namelist MIXTURE PARAMETERS'
       WRITE(*,*) 'Please check the values of rvolcgas',volcgas_mass_fraction0(1:n_gas)
       STOP
       
    END IF

    
    IF ( ( SUM( volcgas_mass_fraction0(1:n_gas) ) + water_mass_fraction0 )      &
         .GE. 1.D0 ) THEN

       WRITE(*,*) 'WARNING: Sum of gas mass fractions :',                       &
            SUM( volcgas_mass_fraction0(1:n_part) + water_mass_fraction0 )

       !READ(*,*)

    END IF
    
    rvolcgas_mix = 0.D0
    cpvolcgas_mix = 0.D0
    Rrhovolcgas_mix = 0.D0

    CALL zmet

    IF ( n_gas .GT. 0 ) THEN

       DO i_gas = 1,n_gas
          
          rvolcgas_mix = rvolcgas_mix + volcgas_mass_fraction0(i_gas)              &
               * rvolcgas(i_gas)
          
          cpvolcgas_mix = cpvolcgas_mix + volcgas_mass_fraction0(i_gas)            &
               * cpvolcgas(i_gas)
          
          Rrhovolcgas_mix = Rrhovolcgas_mix + volcgas_mass_fraction0(i_gas)        &
               / (  pa / ( rvolcgas(i_gas) * t_mix0 ) )
          
       END DO
       
       rvolcgas_mix = rvolcgas_mix / SUM( volcgas_mass_fraction0(1:n_gas) )
       
       cpvolcgas_mix = cpvolcgas_mix / SUM( volcgas_mass_fraction0(1:n_gas) )
       
       rhovolcgas_mix =  SUM(volcgas_mass_fraction0(1:n_gas)) / Rrhovolcgas_mix
       
       volcgas_mix_mass_fraction = SUM(volcgas_mass_fraction0(1:n_gas))
    
    ELSE

       rvolcgas_mix = 0.D0
       
       cpvolcgas_mix = 0.D0
       
       rhovolcgas_mix =  0.D0
       
       volcgas_mix_mass_fraction = 0.D0
    
    END IF

    IF ( verbose_level .GE. 1 ) THEN

       WRITE(*,*) 'volcgas_mix_mass_fraction',volcgas_mix_mass_fraction

    END IF

    rhowv = pa / ( rwv * t_mix0 )

    ! ---- We assume all volcanic H2O at the vent is water vapor 
    water_vapor_mass_fraction = water_mass_fraction0

    liquid_water_mass_fraction = 0.D0

    gas_mass_fraction = water_vapor_mass_fraction + volcgas_mix_mass_fraction 

    IF ( n_gas .GT. 0 ) THEN

       rho_gas = gas_mass_fraction / (  water_vapor_mass_fraction / rhowv          &
            + volcgas_mix_mass_fraction / rhovolcgas_mix )  
       
    ELSE

       rho_gas = rhowv

    END IF

    IF ( verbose_level .GE. 1 ) THEN
       
       WRITE(*,*) 'rvolcgas_mix :', rvolcgas_mix
       WRITE(*,*) 'cpvolcgas_mix :', cpvolcgas_mix
       WRITE(*,*) 'rhovolcgas_mix :', rhovolcgas_mix
       WRITE(*,*) 'rhowv :', rhowv
       WRITE(*,*) 'rho_gas :', rho_gas 
       !READ(*,*)
       
    END IF
    
    WRITE(bak_unit, mixture_parameters) 

    IF ( verbose_level .GE. 1 ) WRITE(*,*) 'read mixture_parameters: done'
    
    IF ( aggregation_flag ) THEN

       i_aggr = 0

       DO i_part = 1, n_part_org

          IF ( aggregation_array(i_part) ) THEN

             i_aggr = i_aggr + 1

             aggr_idx(i_part) = n_part_org + i_aggr
             aggr_idx(n_part_org + i_aggr) = i_part

             diam1( n_part_org + i_aggr ) = diam1(i_part)
             rho1( n_part_org + i_aggr ) = ( 1.D0 - aggregate_porosity(i_part) )   &
                  * rho1(i_part)
             diam2( n_part_org + i_aggr ) = diam2(i_part)
             rho2( n_part_org + i_aggr ) = ( 1.D0 - aggregate_porosity(i_part) )   &
                  * rho2(i_part)
             cp_part( n_part_org + i_aggr ) = cp_part(i_part)

          END IF

       END DO

    END IF

    IF ( distribution .EQ. 'beta' ) THEN

       ALLOCATE( p_beta(n_part) )
       ALLOCATE( q_beta(n_part) )
       ALLOCATE( d_max(n_part) )

       READ(inp_unit, beta_parameters)
       WRITE(bak_unit, beta_parameters)

       IF ( aggregation_flag ) THEN

          i_aggr = 0

          DO i_part = 1, n_part_org

             IF ( aggregation_array(i_part) ) THEN

                i_aggr = i_aggr + 1

                p_beta( n_part_org + i_aggr ) = p_beta(i_part)
                q_beta( n_part_org + i_aggr ) = q_beta(i_part)
                d_max( n_part_org + i_aggr ) = d_max(i_part)

             END IF

          END DO

       END IF
       
    ELSEIF ( distribution .EQ. 'lognormal' ) THEN

       ALLOCATE( mu_lognormal(n_part) )
       ALLOCATE( sigma_lognormal(n_part) )

       ALLOCATE( mu_bar(n_part) )
       ALLOCATE( sigma_bar(n_part) )

       READ(inp_unit, lognormal_parameters)
       WRITE(bak_unit, lognormal_parameters)
       
       IF ( aggregation_flag ) THEN

          i_aggr = 0

          DO i_part = 1, n_part_org

             IF ( mu_lognormal(i_part) .EQ. 0.D0) mu_lognormal(i_part) = 1.D-5

             IF ( aggregation_array(i_part) ) THEN

                i_aggr = i_aggr + 1

                solid_partial_mass_fraction( n_part_org + i_aggr ) = 0.0001D0      &
                     * solid_partial_mass_fraction(i_part)

                solid_partial_mass_fraction( i_part ) = 0.9999D0                   &
                     * solid_partial_mass_fraction(i_part)

                mu_lognormal( n_part_org + i_aggr ) = mu_lognormal(i_part)
                sigma_lognormal( n_part_org + i_aggr ) = sigma_lognormal(i_part)

             END IF

          END DO

       END IF

       mu_bar = -log( 2.D0 ) * mu_lognormal
       sigma_bar = log( 2.D0 ) * sigma_lognormal

       ! WRITE(*,*) 'mu_bar',mu_bar
       ! WRITE(*,*) 'sigma_bar',sigma_bar


    ELSEIF ( distribution .EQ. 'constant' ) THEN

       ALLOCATE( diam_constant(n_part) )
       ALLOCATE( diam_constant_phi(n_part) )

       READ(inp_unit, constant_parameters)
       WRITE(bak_unit, constant_parameters)
       
       IF ( aggregation_flag ) THEN

          i_aggr = 0

          DO i_part = 1, n_part_org

             IF ( aggregation_array(i_part) ) THEN

                i_aggr = i_aggr + 1

                solid_partial_mass_fraction( n_part_org + i_aggr ) = 0.0001D0      &
                     * solid_partial_mass_fraction(i_part)

                solid_partial_mass_fraction( i_part ) = 0.9999D0                   &
                     * solid_partial_mass_fraction(i_part)

                diam_constant_phi( n_part_org + i_aggr ) = diam_constant_phi(i_part)

             END IF

          END DO

       END IF

       WHERE ( diam_constant_phi .EQ. 0.D0) diam_constant_phi=1.D-5
       diam_constant = 1.D-3 * 2.D0**(-diam_constant_phi)

    END IF

    IF ( SUM( solid_partial_mass_fraction(1:n_part) ) .NE. 1.D0 ) THEN

       WRITE(*,*) 'WARNING: Sum of solid mass fractions :',                     &
            SUM( solid_partial_mass_fraction(1:n_part) )

       solid_partial_mass_fraction(1:n_part) =                                  &
            solid_partial_mass_fraction(1:n_part)                               &
            / SUM( solid_partial_mass_fraction(1:n_part) )

       IF ( verbose_level .GE. 1 ) THEN

          WRITE(*,*) '         Modified solid mass fractions :',                &
               solid_partial_mass_fraction(1:n_part)

       END IF


    END IF

    ! solid mass fractions in the mixture
    solid_mass_fraction(1:n_part) = ( 1.d0 - water_mass_fraction0               &
         - volcgas_mix_mass_fraction ) * solid_partial_mass_fraction(1:n_part)

    ALLOCATE( xi(n_nodes) )
    ALLOCATE( wi(n_nodes) )
    ALLOCATE( part_dens_array(n_nodes) )

    ! evaluate the moments from the parameters of the beta distribution
    ! these moments have to be corrected for the mass fractions give in
    ! the input file

    IF ( distribution_variable .EQ. 'mass_fraction' ) THEN
       
       ALLOCATE( coeff(0:n_mom,0:n_mom) )
       CALL coefficient(n_mom,coeff)

    END IF

    DO i_part = 1,n_part

       IF ( verbose_level .GE. 1 ) WRITE(*,*) 'i_part',i_part

       DO i = 0, n_mom-1

          IF ( distribution_variable .EQ. 'mass_fraction' ) THEN

             IF ( distribution .EQ. 'lognormal' ) THEN

                IF ( mu_lognormal(i_part) .EQ. 0.D0) mu_lognormal(i_part) = 1.D-5

                mom0(i_part,i) = 0.d0
                
                DO k=0,floor(0.5D0 * i)
                
                   fact2 = product ((/(j, j = 2*k-1,1,-2)/))

                   mom0(i_part,i) = mom0(i_part,i) + coeff(i,2*k) * fact2       &
                        * sigma_lognormal(i_part)**(2*k) *                      &
                        mu_lognormal(i_part)**(i-2*k)

                END DO


             ELSEIF ( distribution .EQ. 'constant' ) THEN

                mom0(i_part,i) = diam_constant_phi(i_part)**i
                

             END IF

          END IF

       END DO

       CALL wheeler_algorithm( mom0(i_part,0:n_mom-1) , distribution , xi , wi )
 
       DO i=1,n_nodes

          part_dens_array(i) = particles_density( i_part , xi(i) )

       END DO

       IF ( verbose_level .GE. 1 ) THEN

          WRITE(*,*) 'part_dens_array'
          WRITE(*,*) 'xi',xi
          WRITE(*,*) 'wi',wi
          WRITE(*,*) 'rho',part_dens_array

       END IF

       ! the density of the particles phases are evaluated here. It is 
       ! independent from the mass fraction of the particles phases, so
       ! it is possible to evaluate them with the "uncorrected" moments

       IF ( distribution_variable .EQ. 'mass_fraction' ) THEN

          rho_solid_avg(i_part) = 1.D0 / ( SUM( wi / part_dens_array ) /        &
               mom0(i_part,0) )

       ELSE

          WRITE(*,*) 'input_file: distribution_variable',distribution_variable
          STOP

       END IF

       IF ( verbose_level .GE. 1 ) THEN

          WRITE(*,*) 'rho avg',rho_solid_avg(i_part)

       END IF

    END DO

    ! the average solid density is evaluated through the mass fractions and 
    ! the densities of the particles phases

    rho_solid_tot_avg = 1.D0 / SUM( solid_partial_mass_fraction(1:n_part) /     &
         rho_solid_avg(1:n_part) )

    IF ( verbose_level .GE. 1 ) THEN

       WRITE(*,*) 
       WRITE(*,*) '******* CHECK ON MASS AND VOLUME FRACTIONS *******'
       WRITE(*,*) 'rho solid avg', rho_solid_tot_avg

    END IF

    IF ( initial_neutral_density ) THEN

       ! CHECK AND CORRECT

       rho_mix = rho_atm

       solid_tot_volume_fraction0 = ( rho_mix - rho_gas ) /                     &
            ( rho_solid_tot_avg - rho_gas )

       water_volume_fraction0 = 1.D0 - solid_tot_volume_fraction0

       water_mass_fraction0 =  water_volume_fraction0 * rho_gas / rho_mix

    ELSE

       gas_volume_fraction = rho_solid_tot_avg / ( rho_gas * ( 1.D0 /          &
            gas_mass_fraction - 1.D0 ) + rho_solid_tot_avg )

       solid_tot_volume_fraction0 = 1.D0 - gas_volume_fraction

       rho_mix = gas_volume_fraction * rho_gas + solid_tot_volume_fraction0    &
            * rho_solid_tot_avg

    END IF

    IF ( verbose_level .GE. 1 ) THEN
       
       WRITE(*,*) 'gas_volume_fraction',gas_volume_fraction
       WRITE(*,*) 'solid_tot_volume_fraction0',solid_tot_volume_fraction0
       WRITE(*,*) 'rho_gas',rho_gas
       WRITE(*,*) 'rho_mix',rho_mix

       WRITE(*,*) 'gas_mass_fraction',gas_mass_fraction
       WRITE(*,*) 'solid_mass_fractions',solid_mass_fraction(1:n_part)

    END IF
    
    DO i_part = 1,n_part

       ! the volume fraction of the particle phases ( with respect to the
       ! solid phase only) is evaluated

       alfa_s = solid_partial_mass_fraction(i_part) * rho_solid_tot_avg /       &
            rho_solid_avg(i_part)

       ! this is the volume fraction of the particles phases in the mixture

       solid_volume_fraction0(i_part) = solid_tot_volume_fraction0 * alfa_s

       ! the coefficient C0 (=mom0) for the particles size distribution is
       ! evaluated in order to have the corrected volume or mass fractions

       IF ( distribution_variable .EQ. 'mass_fraction' ) THEN
          
          C0 = SUM(solid_mass_fraction(1:n_part)) / mom0(i_part,0) *            &
               solid_partial_mass_fraction(i_part)
      
       END IF
       
       ! the moments are corrected with the factor C0

       DO i = 0, n_mom-1

          mom0(i_part,i) = C0 * mom0(i_part,i)

          IF ( verbose_level .GE. 1 ) WRITE(*,*) 'mom',i,mom0(i_part,i)

       END DO

       IF ( verbose_level .GE. 1 ) THEN

          WRITE(*,*) 'i_part =',i_part
          WRITE(*,*) 'tot solid_mass_fract', SUM(solid_mass_fraction(1:n_part))
          WRITE(*,*) 'alfa_s',i_part,alfa_s
          WRITE(*,*) 'solid_volume_fraction0',solid_volume_fraction0(i_part)
          WRITE(*,*) 'solid_partial_mass_fract',                                &
               solid_partial_mass_fraction(i_part)
          WRITE(*,*) 'solid_mass_fract', solid_mass_fraction(i_part)
          WRITE(*,*) mom0(i_part,1:n_mom-1)
          WRITE(*,*) 

       END IF

    END DO

    IF ( verbose_level .GE. 1 ) THEN

       IF ( distribution_variable .EQ. 'mass_fraction' ) THEN
          
          WRITE(*,*) 'solid_mass_fractions', mom0(1:n_part,0)
          
       END IF

       WRITE(*,*) 'gas volume fraction', gas_volume_fraction
       WRITE(*,*) 'gas mass fraction', gas_mass_fraction
       
    END IF

    ! the parameters of the particles phases distributions are saved in a file 
    ! readable by Matlab

    IF ( .NOT. dakota_flag ) THEN

       n_unit = n_unit + 1
       
       mat_unit = n_unit
       
       mat_file = TRIM(run_name)//'.m'
       
       OPEN(mat_unit,file=mat_file,status='unknown')
       
       WRITE(mat_unit,*) 'n_part = ',n_part,';'
       WRITE(mat_unit,*) 'n_gas = ',n_gas,';'
       WRITE(mat_unit,*) 'gas_volume_fraction = ',gas_volume_fraction,';'
       
       IF ( distribution .EQ. 'beta' ) THEN
          
          WRITE(mat_unit,*) 'p = [',p_beta(1:n_part),'];'
          WRITE(mat_unit,*) 'q = [',q_beta(1:n_part),'];' 
          WRITE(mat_unit,*) 'd_max = [',d_max(1:n_part),'];'
          
          
       ELSEIF ( distribution .EQ. 'lognormal' ) THEN
          
          WRITE(mat_unit,*) 'mu = [',mu_lognormal(1:n_part),'];'
          WRITE(mat_unit,*) 'sigma = [',sigma_lognormal(1:n_part),'];' 
          
       ELSEIF ( distribution .EQ. 'constant' ) THEN
          
          WRITE(mat_unit,*) 'diam = [',diam_constant(1:n_part),'];'
          
       END IF
       
       WRITE(mat_unit,*) 'solid_mass_fractions = [',                            &
            solid_partial_mass_fraction(1:n_part),'];'
       
       WRITE(mat_unit,*) 'd1 = [',diam1(1:n_part),'];'
       WRITE(mat_unit,*) 'd2 = [',diam2(1:n_part),'];'
       WRITE(mat_unit,*) 'rho1 = [',rho1(1:n_part),'];'
       WRITE(mat_unit,*) 'rho2 = [',rho2(1:n_part),'];'
              
       IF ( verbose_level .GE. 1 ) WRITE(*,*) 'Write matlab file: done' 
       
       CLOSE(mat_unit)
       
    END IF

    ! the parameters of the particles phases distributions are saved in a file 
    ! readable by Python

    IF ( .NOT. dakota_flag ) THEN

       n_unit = n_unit + 1
       
       py_unit = n_unit
       
       py_file = TRIM(run_name)//'.py'
       
       OPEN(py_unit,file=py_file,status='unknown')
       
       WRITE(py_unit,111) 'n_part = ',n_part
       WRITE(py_unit,111) 'n_gas  = ',n_gas
       WRITE(py_unit,112) 'gas_volume_fraction = ',gas_volume_fraction
       
       IF ( distribution .EQ. 'beta' ) THEN

          WRITE(py_unit,113,advance="no") 'p                    = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") p_beta(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") p_beta(n_part)
          WRITE(py_unit,117) ' ] '


          WRITE(py_unit,113,advance="no") 'q                    = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") q_beta(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") q_beta(n_part)
          WRITE(py_unit,117) ' ] '

          WRITE(py_unit,113,advance="no") 'd_max                = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") d_max(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") d_max(n_part)
          WRITE(py_unit,117) ' ] '



          !WRITE(py_unit,*) 'q = [',q_beta(1:n_part),'];' 
          !WRITE(py_unit,*) 'd_max = [',d_max(1:n_part),'];'
          
          
       ELSEIF ( distribution .EQ. 'lognormal' ) THEN


          WRITE(py_unit,113,advance="no") 'mu                   = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") mu_lognormal(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") mu_lognormal(n_part)
          WRITE(py_unit,117) ' ] '


          WRITE(py_unit,113,advance="no") 'sigma                = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") sigma_lognormal(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") sigma_lognormal(n_part)
          WRITE(py_unit,117) ' ] '


          
          
         
          
       ELSEIF ( distribution .EQ. 'constant' ) THEN

          WRITE(py_unit,113,advance="no") 'diam                 = [ '

          DO i = 1, n_part-1
         
              WRITE(py_unit,114,advance="no") diam_constant(i)
              WRITE(py_unit,115,advance="no") ' , '

          END DO

          WRITE(py_unit,116,advance="no") diam_constant(n_part)
          WRITE(py_unit,117) ' ] '



          
          !WRITE(py_unit,*) 'diam = [',diam_constant(1:n_part),'];'
          
       END IF


       WRITE(py_unit,113,advance="no") 'solid_mass_fractions = [ '

       DO i = 1, n_part-1
         
           WRITE(py_unit,114,advance="no") solid_partial_mass_fraction(i)
           WRITE(py_unit,115,advance="no") ' , '

       END DO

       WRITE(py_unit,116,advance="no") solid_partial_mass_fraction(n_part)
       WRITE(py_unit,117) ' ] '



       WRITE(py_unit,113,advance="no") 'd1                   = [ '

       DO i = 1, n_part-1
         
           WRITE(py_unit,114,advance="no") diam1(i)
           WRITE(py_unit,115,advance="no") ' , '

       END DO

       WRITE(py_unit,116,advance="no") diam1(n_part)
       WRITE(py_unit,117) ' ] '

       WRITE(py_unit,113,advance="no") 'd2                   = [ '

       DO i = 1, n_part-1
         
           WRITE(py_unit,114,advance="no") diam2(i)
           WRITE(py_unit,115,advance="no") ' , '

       END DO

       WRITE(py_unit,116,advance="no") diam2(n_part)
       WRITE(py_unit,117) ' ] '

       WRITE(py_unit,113,advance="no") 'rho1                 = [ '

       DO i = 1, n_part-1
         
           WRITE(py_unit,114,advance="no") rho1(i)
           WRITE(py_unit,115,advance="no") ' , '

       END DO

       WRITE(py_unit,116,advance="no") rho1(n_part)
       WRITE(py_unit,117) ' ] '

       WRITE(py_unit,113,advance="no") 'rho2                 = [ '

       DO i = 1, n_part-1
         
           WRITE(py_unit,114,advance="no") rho2(i)
           WRITE(py_unit,115,advance="no") ' , '

       END DO

       WRITE(py_unit,116,advance="no") rho2(n_part)
       WRITE(py_unit,117) ' ] '
      
       IF ( verbose_level .GE. 1 ) WRITE(*,*) 'Write python file: done' 

111    FORMAT(A9,I1)
112    FORMAT(A22,F20.10)

113    FORMAT(A25)
114    FORMAT(F20.10)
115    FORMAT(A3)
116    FORMAT(F20.10)
117    FORMAT(A3)
       
       CLOSE(py_unit)
       
    END IF



    tend1 = .FALSE.
    
    IF ( distribution .EQ. 'moments' ) THEN

       moments_search: DO

          READ(inp_unit , *, END = 300 ) card

          IF( TRIM(card) == 'MOMENTS' ) THEN

             EXIT moments_search

          END IF

       END DO moments_search

       READ(inp_unit,*) n_mom

       WRITE(*,*) 'input_moments'

       READ(inp_unit,*) solid_partial_mass_fraction(1:n_part)

       DO i = 0, n_mom-1

          READ(inp_unit,*) mom0(1:n_part,i)

          WRITE(*,*) mom0(1:n_part,i)

       END DO

       GOTO 310
300    tend1 = .TRUE.
310    CONTINUE

    END IF

    ! Close input file

    CLOSE(inp_unit)

    ! Write a backup of the input file 

    IF ( distribution .EQ. 'moments' ) THEN
       
       IF (( tend1 ) .OR. ( n_mom .EQ. 0 )) THEN

          WRITE(*,*) 'WARNING: input ', ' SAMPLING POINTS not found '

       ELSE

          WRITE(bak_unit,*) '''MOMENTS'''
          WRITE(bak_unit,*) n_mom

           DO i = 0, n_mom-1

             WRITE(bak_unit,*) mom0(1:n_part,i)

          END DO

       END IF

    END IF

    IF ( read_atm_profile .EQ. 'card' ) THEN

       WRITE(bak_unit,*) '''ATM_PROFILE'''
       WRITE(bak_unit,*) n_atm_profile
       
       DO i = 1, n_atm_profile
          
          WRITE(bak_unit,107) atm_profile0(1:7,i)
  
107 FORMAT(7(1x,es14.7))

        
       END DO
       
    END IF

    CLOSE(bak_unit)

    IF ( verbose_level .GE. 1 ) WRITE(*,*) 'end subroutine reainp'

    RETURN

  END SUBROUTINE read_inp

  !******************************************************************************
  !> \brief Initialize output units
  !
  !> This subroutine set the names of the output files and open the output units
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE open_file_units

    ! External variables
    USE particles_module, ONLY : n_part
    USE moments_module, ONLY : n_mom
    USE variables, ONLY : dakota_flag , hysplit_flag

    IMPLICIT NONE
    
    
    col_file = TRIM(run_name)//'.col'
    mom_file = TRIM(run_name)//'.mom'
    dak_file = TRIM(run_name)//'.dak' 
    hy_file = TRIM(run_name)//'.hy'
    hy_file_volcgas = TRIM(run_name)//'_volcgas.hy'
    inversion_file = TRIM(run_name)//'.inv'
    
    IF ( .NOT.dakota_flag ) THEN

       n_unit = n_unit + 1
       col_unit = n_unit
       
       OPEN(col_unit,FILE=col_file)

       n_unit = n_unit + 1
       mom_unit = n_unit
       
       OPEN(mom_unit,FILE=mom_file)
       
       
       WRITE(mom_unit,*) n_part
       WRITE(mom_unit,*) n_mom

    END IF

    n_unit = n_unit + 1
    hy_unit = n_unit

    IF ( hysplit_flag ) THEN
       
       OPEN(hy_unit,FILE=hy_file)
       
    END IF

    n_unit = n_unit + 1
    dak_unit = n_unit

    OPEN(dak_unit,FILE=dak_file)

    IF ( inversion_flag ) THEN
    
       n_unit = n_unit + 1
       inversion_unit = n_unit
       
       OPEN(inversion_unit,FILE=inversion_file)
       WRITE(inversion_unit,187)
187    FORMAT(1x,'      radius (m) ',1x,' velocity (m/s) ',1x,                  &
            'MER (kg/s)     ',  1x,'plume height (m)',1x,                       &
            ' inversion ',1x,'column regime')
       
    END IF
    
    RETURN
    
  END SUBROUTINE open_file_units

  !******************************************************************************
  !> \brief Close output units
  !
  !> This subroutine close the output units
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE close_file_units

    USE variables, ONLY : dakota_flag , hysplit_flag

    IMPLICIT  NONE

    IF ( .not.dakota_flag ) THEN

       CLOSE(col_unit)
       CLOSE(mom_unit)

    END IF

    IF ( hysplit_flag ) CLOSE ( hy_unit )

    CLOSE(dak_unit)

    IF ( inversion_flag ) CLOSE ( inversion_unit )
    
    RETURN

  END SUBROUTINE close_file_units

  !******************************************************************************
  !> \brief Write outputs
  !
  !> This subroutine writes the output values on the output files. The values
  !> are saved along the column.
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE write_column

    USE meteo_module, ONLY: rho_atm , ta, pa

    USE particles_module, ONLY: n_mom , n_part , solid_partial_mass_fraction ,  &
         mom , set_mom

    USE plume_module, ONLY: x , y , z , w , r , mag_u

    USE mixture_module, ONLY: rho_mix , t_mix , atm_mass_fraction ,             &
         volcgas_mix_mass_fraction , volcgas_mass_fraction,                     &
         dry_air_mass_fraction , water_vapor_mass_fraction ,                    & 
         liquid_water_mass_fraction, ice_mass_fraction

    ! USE plume_model, ONLY : gas_mass_fraction


    USE variables, ONLY: verbose_level

    IMPLICIT NONE

    REAL*8 :: mfr

    INTEGER :: i_part , j_part , i_mom

    INTEGER :: i_gas

    mfr = 3.14 * r**2 * rho_mix * mag_u

    ! WRITE(*,*) 'INPOUT: atm_mass_fraction',atm_mass_fraction
    ! READ(*,*)

    IF ( z .EQ. vent_height ) THEN

       col_lines = 0

       WRITE(col_unit,97,advance="no")
       
       DO i_part=1,n_part_org
          
          WRITE(col_unit,98,advance="no")

          IF ( aggregation_array(i_part) ) WRITE(col_unit,198,advance="no")
          
       END DO

       DO i_gas=1,n_gas
          
          WRITE(col_unit,99,advance="no")
          
       END DO
       
       WRITE(col_unit,100)
       
97     FORMAT(1x,'     z(m)      ',1x,'       r(m)     ',1x,'      x(m)     ',  &
            1x,'     y(m)      ',1x,'mix.dens(kg/m3)',1x,'temperature(C)',      &
            1x,' vert.vel.(m/s)',1x,' mag.vel.(m/s) ',1x,' d.a.massfract ',     &
            1x,' w.v.massfract ',1x,' l.w.massfract ',1x' i.massfract ',1x)


98     FORMAT(1x,'sol.massfract ')
198    FORMAT(1x,'agr.massfract ')

99     FORMAT(1x,'  volgas.massf ')
       
100     FORMAT(1x,' volgasmix.massf',1x,'atm.rho(kg/m3)',1x,' MFR(kg/s)      ', &
             1x,'atm.temp(K)   ', 1x,' atm.pres.(Pa) ')
       

    END IF

    col_lines = col_lines + 1

    WRITE(col_unit,101,advance="no") z , r , x , y , rho_mix , t_mix-273.15D0 , &
         w , mag_u, dry_air_mass_fraction , water_vapor_mass_fraction ,         & 
         liquid_water_mass_fraction , ice_mass_fraction

101 FORMAT(12(1x,es15.8))
    
    DO i_part=1,n_part_org

       WRITE(col_unit,102,advance="no") solid_partial_mass_fraction(i_part)

       IF ( aggregation_array(i_part) ) THEN

          j_part = aggr_idx(i_part)

          WRITE(col_unit,102,advance="no") solid_partial_mass_fraction(j_part)

       END IF
          
    END DO

102 FORMAT(1(1x,es15.8))

    
    WRITE(col_unit,103) volcgas_mass_fraction(1:n_gas) ,                        &
         volcgas_mix_mass_fraction , rho_atm , mfr , ta, pa

103 FORMAT(20(1x,es15.8))

    !WRITE(mom_unit,*) z , mom(1:n_part,0:n_mom-1),set_mom(1:n_part,0)

    WRITE(mom_unit,104,advance="no") z

104 FORMAT(1(1x,es15.8))

   DO i_mom=0,n_mom-1

       DO i_part=1,n_part_org
  
           WRITE(mom_unit,105,advance="no")  mom(i_part,i_mom)

           IF ( aggregation_array(i_part) ) THEN

               j_part = aggr_idx(i_part)

               WRITE(mom_unit,105,advance="no") mom(j_part,i_mom)

           END IF

       END DO

   END DO

105 FORMAT(1(1x,es15.8))

    WRITE(mom_unit,*) " "
    
    IF ( verbose_level .GE. 1 ) THEN
       
       WRITE(*,*) '******************'
       WRITE(*,*) 'z',z
       WRITE(*,*) 'x',x
       WRITE(*,*) 'y',y
       WRITE(*,*) 'r',r
       WRITE(*,*) 'w',w
       WRITE(*,*) '******************'
       
    END IF
    
    RETURN

  END SUBROUTINE write_column

  !*****************************************************************************
  !> \brief Dakota outputs
  !
  !> This subroutine writes the output values used for the sensitivity analysis
  !> by dakota.  
  !> \param[in]    description     descriptor of the output variable
  !> \param[in]    value           value of the output variable
  !> \date 28/10/2013
  !> @author 
  !> Mattia de' Michieli Vitturi
  !******************************************************************************

  SUBROUTINE write_dakota(description,value)
    
    USE variables, ONLY : verbose_level

    IMPLICIT NONE

    CHARACTER(20), INTENT(IN) :: description

    REAL*8, INTENT(IN) :: value

    WRITE(dak_unit,*) description,value
    
    IF ( verbose_level .GE. 2 ) THEN

       WRITE(*,*) description,value
       
    END IF

    RETURN

  END SUBROUTINE write_dakota

  SUBROUTINE write_inversion(r0,w_opt,opt_mfr,opt_height,search_flag, &
            opt_regime)

    REAL*8,INTENT(IN) :: r0,w_opt,opt_mfr,opt_height
    LOGICAL,INTENT(IN) :: search_flag
    INTEGER,INTENT(IN) :: opt_regime
    
    WRITE(inversion_unit,181) r0,w_opt,opt_mfr,opt_height,search_flag,opt_regime
    
181 FORMAT(2(2x,f15.8),1(1x,es15.8),1(1x,f15.6)4x,L,7x,I4)

    

  END SUBROUTINE write_inversion


  SUBROUTINE write_zero_hysplit

    USE particles_module, ONLY: n_part
    
    IMPLICIT NONE
    
    CHARACTER(len=8) :: x1 ! format descriptor

    INTEGER :: i

    REAL*8, ALLOCATABLE :: delta_solid(:)
    
    OPEN(hy_unit,FILE=hy_file)
    
    WRITE(hy_unit,107,advance="no")
    
    DO i=1,n_part
       
       WRITE(x1,'(I2.2)') i ! converting integer to string using a 'internal file'
       
       WRITE(hy_unit,108,advance="no") 'S mfr'//trim(x1)//' (kg/s)'
       
    END DO
    
    WRITE(hy_unit,*) ''

    ALLOCATE( delta_solid(n_part) )
    
    delta_solid(1:n_part) = 0.D0
   
    WRITE(hy_unit,110) 0.D0 , 0.D0  , vent_height + 0.5D0 * hy_deltaz ,         &
         delta_solid(1:n_part)

    DEALLOCATE( delta_solid )

    CLOSE(hy_unit)
    
107 FORMAT(1x,'     x (m)     ',1x,'      y (m)    ', 1x,'     z (m)     ')
    
108 FORMAT(2x,A)
    
110 FORMAT(50(1x,e15.8))
    
  END SUBROUTINE write_zero_hysplit
  
  !*****************************************************************************
  !> \brief Dakota outputs
  !
  !> This subroutine writes the output values used for the coupled PlumeMoM/
  !> Hysplit procedure.  
  !> \date 11/06/2018
  !> @authors 
  !> Mattia de' Michieli Vitturi, Federica Pardini
  !******************************************************************************
  
  SUBROUTINE check_hysplit

    USE meteo_module, ONLY: rho_atm , ta, pa , interp_1d_scalar
    USE meteo_module, ONLY : cos_theta , sin_theta , u_atm , zmet 

    USE particles_module, ONLY: n_mom , n_part , solid_partial_mass_fraction , &
         mom , set_mom

    USE plume_module, ONLY: x , y , z , w , r , mag_u

    USE mixture_module, ONLY: rho_mix , t_mix , atm_mass_fraction ,            &
         volcgas_mix_mass_fraction , volcgas_mass_fraction,                    &
         dry_air_mass_fraction , water_vapor_mass_fraction ,                   & 
         liquid_water_mass_fraction, ice_mass_fraction

    USE variables, ONLY : height_nbl

    IMPLICIT NONE

    CHARACTER(len=8) :: x1 ! format descriptor

    INTEGER :: i , j , n_hy

    REAL*8 :: temp_k,mfr
    REAL*8 :: da_mf,wv_mf,lw_mf, ice_mf, volcgas_tot_mf
    REAL*8, ALLOCATABLE :: x_col(:) , y_col(:) , z_col(:) , r_col(:) 
    REAL*8, ALLOCATABLE :: solid_pmf(:,:) , gas_mf(:) , mfr_col(:)
    REAL*8, ALLOCATABLE :: volcgas_mf(:,:)
    REAL*8, ALLOCATABLE :: solid_mass_flux(:,:) , solid_mass_loss_cum(:,:)
    REAL*8, ALLOCATABLE :: volcgas_mass_flux(:,:) 
    REAL*8 :: z_min , z_max , z_bot , z_top , x_top , x_bot , y_bot , y_top
    REAL*8 :: r_bot , r_top
    REAL*8 :: solid_bot , solid_top
    REAL*8 :: gas_top
    REAL*8, ALLOCATABLE :: delta_solid(:) , cloud_solid(:)
    REAL*8, ALLOCATABLE :: cloud_gas(:) 
    REAL*8, ALLOCATABLE :: solid_tot(:)


    REAL*8 :: angle_release , start_angle
    REAL*8 :: delta_angle
    REAL*8 :: dx , dy , dz , dv(3) 

    REAL*8 :: vect(3) , vect0(3) , v(3) , c , s
    REAL*8 :: mat_v(3,3) , mat_R(3,3)
    
    ALLOCATE( x_col(col_lines) , y_col(col_lines) , z_col(col_lines) )
    ALLOCATE( r_col(col_lines) )
    ALLOCATE( solid_pmf(n_part,col_lines) )
    ALLOCATE( gas_mf(col_lines) )
    ALLOCATE( mfr_col(col_lines) )
    ALLOCATE( volcgas_mf(n_gas,col_lines) )
    ALLOCATE( solid_mass_flux(n_part,col_lines) )
    ALLOCATE( solid_mass_loss_cum(n_part,col_lines) )
    ALLOCATE( volcgas_mass_flux(n_gas,col_lines) )
    ALLOCATE( delta_solid(n_part) , cloud_solid(n_part) ) 
    ALLOCATE( cloud_gas(n_gas) ) 
    ALLOCATE( solid_tot(n_part) )

    n_unit = n_unit + 1
    read_col_unit = n_unit
    
    OPEN(read_col_unit,FILE=col_file)

    READ(read_col_unit,*)

    DO i = 1,col_lines

       READ(read_col_unit,111) z_col(i) , r_col(i) , x_col(i) , y_col(i) ,      &
	    rho_mix , temp_k , w , mag_u, da_mf , wv_mf , lw_mf , ice_mf,       &
            solid_pmf(1:n_part,i) , volcgas_mf(1:n_gas,i), volcgas_tot_mf,      &
            rho_atm , mfr_col(i) , ta, pa

       gas_mf(i) = da_mf + wv_mf + volcgas_tot_mf

       solid_mass_flux(1:n_part,i) =  solid_pmf(1:n_part,i) * (1.D0 - gas_mf(i) &
            - lw_mf - ice_mf ) * rho_mix * pi_g * r_col(i)**2 * mag_u

       solid_mass_loss_cum(1:n_part,i) = 1.D0 -  solid_mass_flux(1:n_part,i) /  &
            solid_mass_flux(1:n_part,1)

       volcgas_mass_flux(1:n_gas,i) = volcgas_mf(1:n_gas,i)                     &
            *rho_mix * pi_g * r_col(i)**2 * mag_u 

       !WRITE(*,*) 'Solid mass flux (kg/s): ',solid_mass_flux(1:n_part,i)
       !WRITE(*,*) 'Total solid mass flux (kg/s): ',SUM(solid_mass_flux(1:n_part,i))
       !WRITE(*,*) 'solid_pmf: ',solid_pmf(1:n_part,i)
       !WRITE(*,*) 'Sum solid mass fractions: ',SUM(solid_pmf(1:n_part,i))
       !WRITE(*,*) 'gas mass fraction: ',gas_mf(i)
       !WRITE(*,*) z_col(i) , solid_mass_loss_cum(1:n_part,i)
       !READ(*,*)
       !WRITE(*,*) 'volcgas_mass_flux ',volcgas_mass_flux(1:n_gas,i), z_col(i)
       !READ(*,*)

    END DO

111 FORMAT(33(1x,es15.8))

    CLOSE(read_col_unit)    
    
    OPEN(hy_unit,FILE=hy_file)
    
    WRITE(hy_unit,107,advance="no")
    
    DO i=1,n_part
       
       WRITE(x1,'(I2.2)') i ! converting integer to string using a 'internal file'
       
       WRITE(hy_unit,108,advance="no") 'S mfr'//trim(x1)//' (kg/s)'
       
    END DO
    
    WRITE(hy_unit,*) ''

    z_min = z_col(1)

    IF ( nbl_stop ) THEN

       z_max = height_nbl + z_min

    ELSE

       z_max = z_col(col_lines)
       
    END IF

    n_hy = FLOOR( ( z_max - z_min ) / hy_deltaz )

    solid_tot(1:n_part) = 0.D0
    
    DO i = 1,n_hy
   
       z_bot = z_min + (i-1) * hy_deltaz
       z_top = z_min + i * hy_deltaz

       z = z_bot 

       DO j = 1,n_part

          CALL interp_1d_scalar(z_col, solid_mass_flux(j,:), z_bot, solid_bot)
          CALL interp_1d_scalar(z_col, solid_mass_flux(j,:), z_top, solid_top)

          CALL interp_1d_scalar(z_col, x_col, z_bot, x_bot)
          CALL interp_1d_scalar(z_col, x_col, z_top, x_top)

          CALL interp_1d_scalar(z_col, x_col, z_bot, y_bot)
          CALL interp_1d_scalar(z_col, x_col, z_top, y_top)

          CALL interp_1d_scalar(z_col, r_col, z_bot, r_bot)
          CALL interp_1d_scalar(z_col, r_col, z_top, r_top)
          
          delta_solid(j) = solid_bot - solid_top

          !WRITE(*,*) ' solid_mass_flux(j,:) ',solid_mass_flux(j,:)
          !!WRITE(*,*) ' j ',j 
          !WRITE(*,*) ' solid_bot ',solid_bot
          !WRITE(*,*) ' solid_top ',solid_top
          !WRITE(*,*) ' delta_solid(j) ',delta_solid(j)


       END DO

       IF ( n_cloud .EQ. 1 ) THEN
          
          IF ( verbose_level .GE. 1 ) THEN
             
             !WRITE(*,110) 0.5D0 * ( x_top + x_bot ) , 0.5D0 * ( y_top+y_bot ) , &
              !    0.5D0 * ( z_top + z_bot ) , delta_solid(1:n_part)

             !READ(*,*)
             
          END IF
          
          WRITE(hy_unit,110) 0.5D0 * ( x_top+x_bot ) , 0.5D0 * ( y_top+y_bot ) ,&
               0.5D0 * ( z_top + z_bot ) , delta_solid(1:n_part)
          
       ELSE

          CALL zmet
          
          IF ( u_atm .LT. 1.0D+3 ) THEN
   
             delta_angle = 2.D0*pi_g/n_cloud
          
          ELSE

             delta_angle = pi_g / ( n_cloud - 1.D0 )

          END IF

          vect(1) = x_top - x_bot
          vect(2) = y_top - y_bot
          vect(3) = z_top - z_bot

          vect = vect / NORM2( vect )

          vect0(1) = 0
          vect0(2) = 0
          vect0(3) = 1

          v = cross(vect0,vect)

          s = NORM2(v)
   
          c = DOT_PRODUCT(vect0,vect)

          mat_v = 0.D0
          mat_v(2,1) = v(3)
          mat_v(1,2) = -v(3)
          
          mat_v(3,1) = -v(2)
          mat_v(1,3) = v(2)
          
          mat_v(2,3) = -v(1)
          mat_v(3,2) = v(1);

          mat_R = 0.D0

          FORALL(j = 1:3) mat_R(j,j) = 1.D0           
          mat_R = mat_R + mat_v + mat_v**2 * ( 1.D0-c ) / s**2
          
          DO j=1,n_cloud
             
             start_angle =  DATAN2(sin_theta,cos_theta)
             angle_release = (j-1) * delta_angle - 0.5D0*pi_g

             dx = 0.5D0* ( r_bot + r_top ) * DCOS(start_angle + angle_release)
             dy = 0.5D0* ( r_bot + r_top ) * DSIN(start_angle + angle_release)
             dz = 0.D0
             dv(1) = dx
             dv(2) = dy
             dv(3) = dz

             dx = DOT_PRODUCT(mat_R(1,1:3),dv) 
             dy = DOT_PRODUCT(mat_R(2,1:3),dv) 
             dz = DOT_PRODUCT(mat_R(3,1:3),dv) 
             
             IF ( verbose_level .GE. 1 ) THEN
                
                WRITE(*,110)  0.5D0 * ( x_top + x_bot ) + dx ,                  &
                     0.5D0 * ( y_top + y_bot ) + dy ,                           &
                     0.5D0 * ( z_top + z_bot ) + dz ,                           &
                     delta_solid(1:n_part)/n_cloud
                
             END IF
             
             WRITE(hy_unit,110)   0.5D0 * ( x_top + x_bot ) + dx ,              &
                  0.5D0 * ( y_top + y_bot ) + dy ,                              &
                  0.5D0 * ( z_top + z_bot ) + dz ,                              &
                  delta_solid(1:n_part)/n_cloud
             
          END DO
          
       END IF
       
       solid_tot(1:n_part) = solid_tot(1:n_part) + delta_solid(1:n_part)
       !WRITE(*,*) 'Solid mass released in the atmosphere (kg/s): ', 0.5D0 * ( z_top + z_bot ) , SUM(solid_tot)
       !READ(*,*)

    END DO

    ! WRITE THE RELEASE FROM THE MIDDLE OF LAST INTERVAL 
    
    z_bot = z_min + n_hy * hy_deltaz
    z_top = z_max
    
    DO j = 1,n_part
       
       CALL interp_1d_scalar(z_col, solid_mass_flux(j,:), z_bot, solid_bot)
       CALL interp_1d_scalar(z_col, solid_mass_flux(j,:), z_top, solid_top)

       CALL interp_1d_scalar(z_col, x_col, z_bot, x_bot)
       CALL interp_1d_scalar(z_col, x_col, z_top, x_top)
       
       CALL interp_1d_scalar(z_col, x_col, z_bot, y_bot)
       CALL interp_1d_scalar(z_col, x_col, z_top, y_top)
              
       CALL interp_1d_scalar(z_col, r_col, z_bot, r_bot)
       CALL interp_1d_scalar(z_col, r_col, z_top, r_top)
          
       delta_solid(j) = solid_bot - solid_top
       cloud_solid(j) = solid_top

    END DO

   
    solid_tot(1:n_part) = solid_tot(1:n_part) + delta_solid(1:n_part)
    solid_tot(1:n_part) = solid_tot(1:n_part) + cloud_solid(1:n_part)
     
    IF ( n_cloud .EQ. 1 ) THEN
   
       IF ( verbose_level .GE. 1 ) THEN
          
          WRITE(*,110) 0.5D0 * ( x_top + x_bot ) , 0.5D0 * ( y_top + y_bot ) ,  &
               0.5D0 * ( z_top + z_bot ) , delta_solid(1:n_part)
          
       END IF
       
       WRITE(hy_unit,110) 0.5D0 * ( x_top + x_bot ) , 0.5D0 * ( y_top+y_bot ) , &
            0.5D0 * ( z_top + z_bot ) , delta_solid(1:n_part)
       
    ELSE
       
       IF ( u_atm .LT. 1.0D+3 ) THEN
          
          delta_angle = 2.D0*pi_g/n_cloud
          
       ELSE
          
          delta_angle = pi_g / ( n_cloud - 1.D0 )
          
       END IF
       
       vect(1) = x_top - x_bot
       vect(2) = y_top - y_bot
       vect(3) = z_top - z_bot
       
       vect = vect / NORM2( vect )
       
       vect0(1) = 0
       vect0(2) = 0
       vect0(3) = 1
       
       v = cross(vect0,vect)
       
       s = NORM2(v)
       
       c = DOT_PRODUCT(vect0,vect)
       
       mat_v = 0.D0
       mat_v(2,1) = v(3)
       mat_v(1,2) = -v(3)
       
       mat_v(3,1) = -v(2)
       mat_v(1,3) = v(2)
       
       mat_v(2,3) = -v(1)
       mat_v(3,2) = v(1);
       
       mat_R = 0.D0
       
       FORALL(j = 1:3) mat_R(j,j) = 1.D0           
       mat_R = mat_R + mat_v + mat_v**2 * ( 1.D0-c ) / s**2
       
       
       DO i=1,n_cloud
          
          start_angle =  DATAN2(sin_theta,cos_theta)
          angle_release = (i-1) * delta_angle - 0.5D0*pi_g
          
          dx = 0.5* ( r_bot + r_top ) * DCOS(start_angle + angle_release)
          dy = 0.5* ( r_bot + r_top ) * DSIN(start_angle + angle_release)

          dz = 0.D0
          dv(1) = dx
          dv(2) = dy
          dv(3) = dz
          
          dx = DOT_PRODUCT(mat_R(1,1:3),dv) 
          dy = DOT_PRODUCT(mat_R(2,1:3),dv) 
          dz = DOT_PRODUCT(mat_R(3,1:3),dv) 
          
          IF ( verbose_level .GE. 1 ) THEN
             
             WRITE(*,110)  0.5D0 * ( x_top + x_bot ) + dx ,                  &
                  0.5D0 * ( y_top + y_bot ) + dy ,                           &
                  0.5D0 * ( z_top + z_bot ) + dz ,                           &
                  delta_solid(1:n_part)/n_cloud
             
          END IF
          
          WRITE(hy_unit,110)   0.5D0 * ( x_top + x_bot ) + dx ,              &
               0.5D0 * ( y_top + y_bot ) + dy ,                              &
               0.5D0 * ( z_top + z_bot ) + dz ,                              &
               delta_solid(1:n_part)/n_cloud
                    
       END DO
       
    END IF

    ! WRITE THE RELEASE AT THE TOP OF THE COLUMN (OR NBL.)
    
    IF ( n_cloud .EQ. 1 ) THEN

       IF ( verbose_level .GE. 1 ) THEN
          
          WRITE(*,110) x_top , y_top , z_top , cloud_solid(1:n_part)
          
       END IF
       
       WRITE(hy_unit,110) x_top , y_top , z_top , cloud_solid(1:n_part)
       
    ELSE
       
       IF ( u_atm .LT. 1.0D+3 ) THEN
          
          delta_angle = 2.D0*pi_g/n_cloud
          
       ELSE
          
          delta_angle = pi_g / ( n_cloud - 1.D0 )
          
       END IF
              
       DO i=1,n_cloud
          
          start_angle =  DATAN2(sin_theta,cos_theta)
          angle_release = (i-1) * delta_angle - 0.5D0*pi_g
          
          dx = 0.5* ( r_bot + r_top ) * DCOS(start_angle + angle_release)
          dy = 0.5* ( r_bot + r_top ) * DSIN(start_angle + angle_release)
          dz = 0.D0
          dv(1) = dx
          dv(2) = dy
          dv(3) = dz
          
          dx = DOT_PRODUCT(mat_R(1,1:3),dv) 
          dy = DOT_PRODUCT(mat_R(2,1:3),dv) 
          dz = DOT_PRODUCT(mat_R(3,1:3),dv) 
   
          
          IF ( verbose_level .GE. 1 ) THEN

             WRITE(*,110) x_top+dx , y_top+dy , z_top+dz ,                      &
                  cloud_solid(1:n_part)/n_cloud
             
          END IF
          
          WRITE(hy_unit,110) x_top+dx , y_top+dy , z_top+dz ,                   &
               cloud_solid(1:n_part)/n_cloud
          
       END DO

    END IF


    ! WRITE(*,*) 'z_max',z_max
    WRITE(*,*) 'Solid mass released in the atmosphere (kg/s): ',SUM(solid_tot)



107 FORMAT(1x,'     x (m)     ',1x,'      y (m)    ', 1x,'     z (m)     ')
    
108 FORMAT(2x,A)
    
110 FORMAT(50(1x,e15.8))


    ! Write hysplit file for volcanig gas only

    OPEN(hy_unit_volcgas,FILE=hy_file_volcgas)
    
    WRITE(hy_unit_volcgas,207,advance="no")
    
    DO i=1,n_gas
       
       WRITE(x1,'(I2.2)') i ! converting integer to string using a 'internal file'
       
       WRITE(hy_unit_volcgas,208,advance="no") 'VG fr '//trim(x1)//' (kg/s)'
       
    END DO


    WRITE(hy_unit_volcgas,*) ''

    z_min = z_col(1)

    IF ( nbl_stop ) THEN

       z_max = height_nbl + z_min

    ELSE

       z_max = z_col(col_lines)
       
    END IF

  
    ! WRITE(*,*) 'z_min',z_min
  
    n_hy = FLOOR( ( z_max - z_min ) / hy_deltaz )

    z_bot = z_min + n_hy * hy_deltaz
    z_top = z_max

    !WRITE(*,*) 'volcgas_mass_flux : ',volcgas_mass_flux(n_gas,:)
    DO j = 1,n_gas
       

       CALL interp_1d_scalar(z_col, volcgas_mass_flux(j,:), z_top, gas_top)

       CALL interp_1d_scalar(z_col, x_col, z_bot, x_bot)
       CALL interp_1d_scalar(z_col, x_col, z_top, x_top)
       
       CALL interp_1d_scalar(z_col, x_col, z_bot, y_bot)
       CALL interp_1d_scalar(z_col, x_col, z_top, y_top)
              
       CALL interp_1d_scalar(z_col, r_col, z_bot, r_bot)
       CALL interp_1d_scalar(z_col, r_col, z_top, r_top)
          
       
       cloud_gas(j) = gas_top

    END DO
  
    !WRITE(*,*) 'cloud_gas(j) : ',gas_top
    !WRITE(*,*) 'cloud_gas(1:n_gas) : ',cloud_gas(1:n_gas)


    IF ( n_cloud .EQ. 1 ) THEN

       IF ( verbose_level .GE. 1 ) THEN
          
          WRITE(*,210) x_top , y_top , z_top , cloud_gas(1:n_gas)
          
       END IF
       
       WRITE(hy_unit_volcgas,210) x_top , y_top , z_top , cloud_gas(1:n_gas)
       
    ELSE
       
       IF ( u_atm .LT. 1.0D+3 ) THEN
          
          delta_angle = 2.D0*pi_g/n_cloud
          
       ELSE
          
          delta_angle = pi_g / ( n_cloud - 1.D0 )
          
       END IF
              
       DO i=1,n_cloud
          
          start_angle =  DATAN2(sin_theta,cos_theta)
          angle_release = (i-1) * delta_angle - 0.5D0*pi_g
          
          dx = 0.5* ( r_bot + r_top ) * DCOS(start_angle + angle_release)
          dy = 0.5* ( r_bot + r_top ) * DSIN(start_angle + angle_release)
          
          
          IF ( verbose_level .GE. 1 ) THEN

             WRITE(*,210) x_top+dx , y_top+dy , z_top , cloud_gas(1:n_gas)/n_cloud
             
          END IF
          
          WRITE(hy_unit_volcgas,210) x_top+dx , y_top+dy , z_top , cloud_gas(1:n_gas)/n_cloud
          
       END DO

    END IF


207 FORMAT(1x,'     x (m)     ',1x,'      y (m)    ', 1x,'     z (m)     ')
    
208 FORMAT(2x,A)
    
210 FORMAT(33(1x,e15.8))


  END SUBROUTINE check_hysplit

  FUNCTION cross(a, b)
    REAL*8, DIMENSION(3) :: cross
    REAL*8, DIMENSION(3), INTENT(IN) :: a, b
    
    cross(1) = a(2) * b(3) - a(3) * b(2)
    cross(2) = a(3) * b(1) - a(1) * b(3)
    cross(3) = a(1) * b(2) - a(2) * b(1)

  END FUNCTION cross


  FUNCTION lower( string ) result (new) 
    character(len=*)           :: string 

    character(len=len(string)) :: new 

    integer                    :: i 
    integer                    :: k 
    INTEGER :: length

    length = len(string) 
    new    = string 
    do i = 1,len(string) 
       k = iachar(string(i:i)) 
       if ( k >= iachar('A') .and. k <= iachar('Z') ) then 
          k = k + iachar('a') - iachar('A') 
          new(i:i) = achar(k) 
       endif
    enddo
  end function lower

  
  
END MODULE inpout
