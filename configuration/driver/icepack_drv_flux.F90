!=======================================================================

! Flux variable declarations; these include fields sent from the coupler
! ("in"), sent to the coupler ("out"), written to diagnostic history files
! ("diagnostic"), and used internally ("internal").
!
! author Elizabeth C. Hunke, LANL
!
      module icepack_drv_flux

      use icepack_kinds_mod
      use icepack_drv_domain_size, only: ncat, nilyr, nx
      use icepack_drv_constants, only: c0, c1, c5, c10, c20, c180, dragio, &
          stefan_boltzmann, Tffresh, emissivity
      use icepack_intfc_shared, only: max_aero, max_nbtrcr, &
                max_algae, max_doc, max_don, max_dic, max_fe

      implicit none
      private
      public :: init_coupler_flux, init_history_therm, init_history_dyn, &
                init_flux_atm_ocn, init_history_bgc
      save

      character (char_len), public :: &
         default_season ! seasonal default values for forcing

      !-----------------------------------------------------------------
      ! Dynamics component
      !-----------------------------------------------------------------

      real (kind=dbl_kind), dimension (nx), public :: &

       ! in from atmos (if .not.calc_strair)  
         strax   , & ! wind stress components (N/m^2)
         stray   , & ! 

       ! in from ocean
         uocn    , & ! ocean current, x-direction (m/s)
         vocn    , & ! ocean current, y-direction (m/s)
         ss_tltx , & ! sea surface slope, x-direction (m/m)
         ss_tlty , & ! sea surface slope, y-direction

       ! out to atmosphere
         strairxT, & ! stress on ice by air, x-direction
         strairyT, & ! stress on ice by air, y-direction

       ! out to ocean          T-cell (kg/m s^2)
       ! Note, CICE_IN_NEMO uses strocnx and strocny for coupling
         strocnxT, & ! ice-ocean stress, x-direction
         strocnyT    ! ice-ocean stress, y-direction

       ! diagnostic

      real (kind=dbl_kind), dimension (nx), public :: &
         sig1    , & ! principal stress component
         sig2    , & ! principal stress component
         strairx , & ! stress on ice by air, x-direction
         strairy , & ! stress on ice by air, y-direction
         strocnx , & ! ice-ocean stress, x-direction
         strocny , & ! ice-ocean stress, y-direction
         strtltx , & ! stress due to sea surface slope, x-direction
         strtlty , & ! stress due to sea surface slope, y-direction
         strintx , & ! divergence of internal ice stress, x (N/m^2)
         strinty , & ! divergence of internal ice stress, y (N/m^2)
         daidtd  , & ! ice area tendency due to transport   (1/s)
         dvidtd  , & ! ice volume tendency due to transport (m/s)
         dagedtd , & ! ice age tendency due to transport (s/s)
         dardg1dt, & ! rate of area loss by ridging ice (1/s)
         dardg2dt, & ! rate of area gain by new ridges (1/s)
         dvirdgdt, & ! rate of ice volume ridged (m/s)
         opening     ! rate of opening due to divergence/shear (1/s)

      real (kind=dbl_kind), & 
         dimension (nx,ncat), public :: &
       ! ridging diagnostics in categories
         dardg1ndt, & ! rate of area loss by ridging ice (1/s)
         dardg2ndt, & ! rate of area gain by new ridges (1/s)
         dvirdgndt, & ! rate of ice volume ridged (m/s)
         aparticn,  & ! participation function
         krdgn,     & ! mean ridge thickness/thickness of ridging ice
         ardgn,     & ! fractional area of ridged ice
         vrdgn,     & ! volume of ridged ice
         araftn,    & ! rafting ice area
         vraftn,    & ! rafting ice volume 
         aredistn,  & ! redistribution function: fraction of new ridge area
         vredistn     ! redistribution function: fraction of new ridge volume

       ! restart

      real (kind=dbl_kind), dimension (nx), public :: &
       ! ice stress tensor in each corner of T cell (kg/s^2)
         stressp_1, stressp_2, stressp_3, stressp_4 , & ! sigma11+sigma22
         stressm_1, stressm_2, stressm_3, stressm_4 , & ! sigma11-sigma22
         stress12_1,stress12_2,stress12_3,stress12_4    ! sigma12

      logical (kind=log_kind), &
         dimension (nx), public :: &
         iceumask   ! ice extent mask (U-cell)

       ! internal

      real (kind=dbl_kind), dimension (nx), public :: &
         prs_sig  , & ! replacement pressure, for stress calc
         fm           ! Coriolis param. * mass in U-cell (kg/s)

      !-----------------------------------------------------------------
      ! Thermodynamic component
      !-----------------------------------------------------------------

       ! in from atmosphere (if calc_Tsfc)

      real (kind=dbl_kind), dimension (nx), public :: &
         zlvl    , & ! atm level height (m)
         uatm    , & ! wind velocity components (m/s)
         vatm    , &
         wind    , & ! wind speed (m/s)
         potT    , & ! air potential temperature  (K)
         Tair    , & ! air temperature  (K)
         Qa      , & ! specific humidity (kg/kg)
         rhoa    , & ! air density (kg/m^3)
         swvdr   , & ! sw down, visible, direct  (W/m^2)
         swvdf   , & ! sw down, visible, diffuse (W/m^2)
         swidr   , & ! sw down, near IR, direct  (W/m^2)
         swidf   , & ! sw down, near IR, diffuse (W/m^2)
         flw         ! incoming longwave radiation (W/m^2)

       ! in from atmosphere (if .not. Tsfc_calc)
       ! required for coupling to HadGEM3
       ! NOTE: when in CICE_IN_NEMO mode, these are gridbox mean fields,
       ! not per ice area. When in standalone mode, these are per ice area.

      real (kind=dbl_kind), & 
         dimension (nx,ncat), public :: &
         fsurfn_f   , & ! net flux to top surface, excluding fcondtop
         fcondtopn_f, & ! downward cond flux at top surface (W m-2)
         fsensn_f   , & ! sensible heat flux (W m-2)
         flatn_f        ! latent heat flux (W m-2)

       ! in from atmosphere

      real (kind=dbl_kind), dimension (nx), public :: &
         frain   , & ! rainfall rate (kg/m^2 s)
         fsnow       ! snowfall rate (kg/m^2 s)

       ! in from ocean

      real (kind=dbl_kind), dimension (nx), public :: &
         sss     , & ! sea surface salinity (ppt)
         sst     , & ! sea surface temperature (C)
         frzmlt  , & ! freezing/melting potential (W/m^2)
         frzmlt_init, & ! frzmlt used in current time step (W/m^2)
         Tf      , & ! freezing temperature (C)
         qdp     , & ! deep ocean heat flux (W/m^2), negative upward
         hmix    , & ! mixed layer depth (m)
         daice_da    ! data assimilation concentration increment rate 
                     ! (concentration s-1)(only used in hadgem drivers)

       ! out to atmosphere (if calc_Tsfc)
       ! note Tsfc is in ice_state.F

      real (kind=dbl_kind), dimension (nx), public :: &
         fsens   , & ! sensible heat flux (W/m^2)
         flat    , & ! latent heat flux   (W/m^2)
         fswabs  , & ! shortwave flux absorbed in ice and ocean (W/m^2)
         fswint_ai, & ! SW absorbed in ice interior below surface (W/m^2)
         flwout  , & ! outgoing longwave radiation (W/m^2)
         Tref    , & ! 2m atm reference temperature (K)
         Qref    , & ! 2m atm reference spec humidity (kg/kg)
         Uref    , & ! 10m atm reference wind speed (m/s)
         evap        ! evaporative water flux (kg/m^2/s)

       ! albedos aggregated over categories (if calc_Tsfc)
      real (kind=dbl_kind), dimension(nx), public :: &
         alvdr   , & ! visible, direct   (fraction)
         alidr   , & ! near-ir, direct   (fraction)
         alvdf   , & ! visible, diffuse  (fraction)
         alidf   , & ! near-ir, diffuse  (fraction)
         ! grid-box-mean versions
         alvdr_ai, & ! visible, direct   (fraction)
         alidr_ai, & ! near-ir, direct   (fraction)
         alvdf_ai, & ! visible, diffuse  (fraction)
         alidf_ai, & ! near-ir, diffuse  (fraction)
         ! components for history
         albice    , & ! bare ice albedo
         albsno    , & ! snow albedo
         albpnd    , & ! melt pond albedo
         apeff_ai  , & ! effective pond area used for radiation calculation
         snowfrac  , & ! snow fraction used in radiation
         ! components for diagnostic
         alvdr_init, & ! visible, direct   (fraction)
         alidr_init, & ! near-ir, direct   (fraction)
         alvdf_init, & ! visible, diffuse  (fraction)
         alidf_init    ! near-ir, diffuse  (fraction)

       ! out to ocean 
       ! (Note CICE_IN_NEMO does not use these for coupling.  
       !  It uses fresh_ai,fsalt_ai,fhocn_ai and fswthru_ai)
      real (kind=dbl_kind), dimension (nx), public :: &
         fpond   , & ! fresh water flux to ponds (kg/m^2/s)
         fresh   , & ! fresh water flux to ocean (kg/m^2/s)
         fsalt   , & ! salt flux to ocean (kg/m^2/s)
         fhocn   , & ! net heat flux to ocean (W/m^2)
         fswthru     ! shortwave penetrating to ocean (W/m^2)

       ! internal

      real (kind=dbl_kind), &
         dimension (nx), public :: &
         fswfac  , & ! for history
         scale_factor! scaling factor for shortwave components

      logical (kind=log_kind), public :: &
         update_ocn_f, & ! if true, update fresh water and salt fluxes
         l_mpond_fresh   ! if true, include freshwater feedback from meltponds
                         ! when running in ice-ocean or coupled configuration

      real (kind=dbl_kind), dimension (nx,ncat), public :: &
         meltsn      , & ! snow melt in category n (m)
         melttn      , & ! top melt in category n (m)
         meltbn      , & ! bottom melt in category n (m)
         congeln     , & ! congelation ice formation in category n (m)
         snoicen         ! snow-ice formation in category n (m)

      real (kind=dbl_kind), dimension (nx,ncat), public :: &
         keffn_top       ! effective thermal conductivity of the top ice layer 
                         ! on categories (W/m^2/K)

      ! quantities passed from ocean mixed layer to atmosphere
      ! (for running with CAM)

      real (kind=dbl_kind), dimension (nx), public :: &
         strairx_ocn , & ! stress on ocean by air, x-direction
         strairy_ocn , & ! stress on ocean by air, y-direction
         fsens_ocn   , & ! sensible heat flux (W/m^2)
         flat_ocn    , & ! latent heat flux   (W/m^2)
         flwout_ocn  , & ! outgoing longwave radiation (W/m^2)
         evap_ocn    , & ! evaporative water flux (kg/m^2/s)
         alvdr_ocn   , & ! visible, direct   (fraction)
         alidr_ocn   , & ! near-ir, direct   (fraction)
         alvdf_ocn   , & ! visible, diffuse  (fraction)
         alidf_ocn   , & ! near-ir, diffuse  (fraction)
         Tref_ocn    , & ! 2m atm reference temperature (K)
         Qref_ocn        ! 2m atm reference spec humidity (kg/kg)

      ! diagnostic

      real (kind=dbl_kind), dimension (nx), public :: &
         fsurf , & ! net surface heat flux (excluding fcondtop)(W/m^2)
         fcondtop,&! top surface conductive flux        (W/m^2)
         fbot,   & ! heat flux at bottom surface of ice (excluding excess) (W/m^2)
         congel, & ! basal ice growth         (m/step-->cm/day)
         frazil, & ! frazil ice growth        (m/step-->cm/day)
         snoice, & ! snow-ice formation       (m/step-->cm/day)
         meltt , & ! top ice melt             (m/step-->cm/day)
         melts , & ! snow melt                (m/step-->cm/day)
         meltb , & ! basal ice melt           (m/step-->cm/day)
         meltl , & ! lateral ice melt         (m/step-->cm/day)
         dsnow,  & ! change in snow thickness (m/step-->cm/day)
         daidtt, & ! ice area tendency thermo.   (s^-1)
         dvidtt, & ! ice volume tendency thermo. (m/s)
         dagedtt,& ! ice age tendency thermo.    (s/s)
         mlt_onset, &! day of year that sfc melting begins
         frz_onset, &! day of year that freezing begins (congel or frazil)
         frazil_diag ! frazil ice growth diagnostic (m/step-->cm/day)
         
      real (kind=dbl_kind), & 
         dimension (nx,ncat), public :: &
         fsurfn,   & ! category fsurf
         fcondtopn,& ! category fcondtop
         fsensn,   & ! category sensible heat flux
         flatn       ! category latent heat flux

      ! As above but these remain grid box mean values i.e. they are not
      ! divided by aice at end of ice_dynamics.  These are used in
      ! CICE_IN_NEMO for coupling and also for generating
      ! ice diagnostics and history files as these are more accurate. 
      ! (The others suffer from problem of incorrect values at grid boxes
      !  that change from an ice free state to an icy state.)
    
      real (kind=dbl_kind), dimension (nx), public :: &
         fresh_ai, & ! fresh water flux to ocean (kg/m^2/s)
         fsalt_ai, & ! salt flux to ocean (kg/m^2/s)
         fhocn_ai, & ! net heat flux to ocean (W/m^2)
         fswthru_ai  ! shortwave penetrating to ocean (W/m^2)

      ! Used with data assimilation in hadgem drivers
      real (kind=dbl_kind), dimension (nx) :: &
         fresh_da, & ! fresh water flux to ocean due to data assim (kg/m^2/s)
         fsalt_da    ! salt flux to ocean due to data assimilation(kg/m^2/s)

      !-----------------------------------------------------------------
      ! internal
      !-----------------------------------------------------------------

      real (kind=dbl_kind), dimension (nx), public :: &
         rside   , & ! fraction of ice that melts laterally
         fsw     , & ! incoming shortwave radiation (W/m^2)
         coszen  , & ! cosine solar zenith angle, < 0 for sun below horizon 
         rdg_conv, & ! convergence term for ridging (1/s)
         rdg_shear   ! shear term for ridging (1/s)
 
      real (kind=dbl_kind), dimension(nx,nilyr+1), public :: &
         salinz    ,&   ! initial salinity  profile (ppt)   
         Tmltz          ! initial melting temperature (^oC)

      !-----------------------------------------------------------------
      ! biogeochemistry
      !-----------------------------------------------------------------

      ! in from atmosphere

      real (kind=dbl_kind), &   !coupling variable for both tr_aero and tr_zaero
         dimension (nx,max_aero), public :: &
         faero_atm   ! aerosol deposition rate (kg/m^2 s)   

      real (kind=dbl_kind), &
         dimension (nx,max_nbtrcr), public :: &
         flux_bio_atm  ! all bio fluxes to ice from atmosphere

      ! in from ocean

      real (kind=dbl_kind), &
         dimension (nx,max_aero), public :: &
         faero_ocn   ! aerosol flux to ocean  (kg/m^2/s)

      ! out to ocean 

      real (kind=dbl_kind), &
         dimension (nx,max_nbtrcr), public :: &
         flux_bio   , & ! all bio fluxes to ocean
         flux_bio_ai    ! all bio fluxes to ocean, averaged over grid cell

      real (kind=dbl_kind), dimension (nx), public :: &
         fzsal_ai, & ! salt flux to ocean from zsalinity (kg/m^2/s) 
         fzsal_g_ai  ! gravity drainage salt flux to ocean (kg/m^2/s) 

      ! internal

      logical (kind=log_kind), public :: &
         cpl_bgc         ! switch to couple BGC via drivers

      real (kind=dbl_kind), dimension (nx,ncat), public :: &
         hin_old     , & ! old ice thickness
         dsnown          ! change in snow thickness in category n (m)

      real (kind=dbl_kind), dimension (nx), public :: &
         nit        , & ! ocean nitrate (mmol/m^3)          
         amm        , & ! ammonia/um (mmol/m^3)
         sil        , & ! silicate (mmol/m^3)
         dmsp       , & ! dmsp (mmol/m^3)
         dms        , & ! dms (mmol/m^3)
         hum        , & ! humic material carbon (mmol/m^3)
         fnit       , & ! ice-ocean nitrate flux (mmol/m^2/s), positive to ocean
         famm       , & ! ice-ocean ammonia/um flux (mmol/m^2/s), positive to ocean
         fsil       , & ! ice-ocean silicate flux (mmol/m^2/s), positive to ocean
         fdmsp      , & ! ice-ocean dmsp (mmol/m^2/s), positive to ocean
         fdms       , & ! ice-ocean dms (mmol/m^2/s), positive to ocean
         fhum       , & ! ice-ocean humic material carbon (mmol/m^2/s), positive to ocean
         fdust          ! ice-ocean dust flux (kg/m^2/s), positive to ocean

      real (kind=dbl_kind), dimension (nx,max_algae), public :: &
         algalN     , & ! ocean algal nitrogen (mmol/m^3) (diatoms, pico, phaeo)
         falgalN        ! ice-ocean algal nitrogen flux (mmol/m^2/s) (diatoms, pico, phaeo)

      real (kind=dbl_kind), dimension (nx,max_doc), public :: &
         doc         , & ! ocean doc (mmol/m^3)  (saccharids, lipids, tbd )
         fdoc            ! ice-ocean doc flux (mmol/m^2/s)  (saccharids, lipids, tbd)

      real (kind=dbl_kind), dimension (nx,max_don), public :: &
         don         , & ! ocean don (mmol/m^3) (proteins and amino acids)
         fdon            ! ice-ocean don flux (mmol/m^2/s) (proteins and amino acids)

      real (kind=dbl_kind), dimension (nx,max_dic), public :: &
         dic         , & ! ocean dic (mmol/m^3) 
         fdic            ! ice-ocean dic flux (mmol/m^2/s) 

      real (kind=dbl_kind), dimension (nx,max_fe), public :: &
         fed, fep    , & ! ocean dissolved and particulate fe (nM) 
         ffed, ffep      ! ice-ocean dissolved and particulate fe flux (umol/m^2/s) 

      real (kind=dbl_kind), dimension (nx,max_aero), public :: &
         zaeros          ! ocean aerosols (mmol/m^3) 

!=======================================================================

      contains

!=======================================================================

! Initialize all fluxes exchanged with flux coupler
! and some data-derived fields
!
! author Elizabeth C. Hunke, LANL

      subroutine init_coupler_flux

      use icepack_drv_arrays_column, only: Cdn_atm
      use icepack_intfc, only: icepack_liquidus_temperature
      use icepack_drv_constants, only: p001,vonkar,zref,iceruf

      integer (kind=int_kind) :: n

      real (kind=dbl_kind) :: fcondtopn_d(6), fsurfn_d(6)

      integer :: i

      data fcondtopn_d / -50.0_dbl_kind,-17.0_dbl_kind,-12.0_dbl_kind, &
                          -9.0_dbl_kind, -7.0_dbl_kind, -3.0_dbl_kind /
      data fsurfn_d    /  0.20_dbl_kind, 0.15_dbl_kind, 0.10_dbl_kind, &
                          0.05_dbl_kind, 0.01_dbl_kind, 0.01_dbl_kind /

      !-----------------------------------------------------------------
      ! fluxes received from atmosphere
      !-----------------------------------------------------------------
      zlvl  (:) = c10             ! atm level height (m)
      rhoa  (:) = 1.3_dbl_kind    ! air density (kg/m^3)
      uatm  (:) = c5              ! wind velocity    (m/s)
      vatm  (:) = c5
      strax (:) = 0.05_dbl_kind
      stray (:) = 0.05_dbl_kind
      fsnow (:) = c0              ! snowfall rate (kg/m2/s)
                                      ! fsnow must be 0 for exact restarts
      if (trim(default_season) == 'winter') then
         ! typical winter values
         potT  (:) = 253.0_dbl_kind  ! air potential temp (K)
         Tair  (:) = 253.0_dbl_kind  ! air temperature  (K)
         Qa    (:) = 0.0006_dbl_kind ! specific humidity (kg/kg)
         swvdr (:) = c0              ! shortwave radiation (W/m^2)
         swvdf (:) = c0              ! shortwave radiation (W/m^2)
         swidr (:) = c0              ! shortwave radiation (W/m^2)
         swidf (:) = c0              ! shortwave radiation (W/m^2)
         flw   (:) = c180            ! incoming longwave rad (W/m^2)
         frain (:) = c0              ! rainfall rate (kg/m2/s)
         do n = 1, ncat                  ! conductive heat flux (W/m^2)
            fcondtopn_f(:,n) = fcondtopn_d(n)
         enddo
         fsurfn_f = fcondtopn_f          ! surface heat flux (W/m^2)
         flatn_f(:,:) = c0           ! latent heat flux (kg/m2/s)
         fsensn_f(:,:) = c0              ! sensible heat flux (W/m^2)
      elseif (trim(default_season) == 'summer') then
         ! typical summer values
         potT  (:) = 273.0_dbl_kind  ! air potential temp (K)
         Tair  (:) = 273.0_dbl_kind  ! air temperature  (K)
         Qa    (:) = 0.0035_dbl_kind ! specific humidity (kg/kg)
         swvdr (:) = 50._dbl_kind    ! shortwave radiation (W/m^2)
         swvdf (:) = 50._dbl_kind    ! shortwave radiation (W/m^2)
         swidr (:) = 50._dbl_kind    ! shortwave radiation (W/m^2)
         swidf (:) = 50._dbl_kind    ! shortwave radiation (W/m^2)
         flw   (:) = 280.0_dbl_kind  ! incoming longwave rad (W/m^2)
         frain (:) = c0              ! rainfall rate (kg/m2/s)
         do n = 1, ncat                  ! surface heat flux (W/m^2)
            fsurfn_f(:,n) = fsurfn_d(n)
         enddo
         fcondtopn_f(:,:) = 0.0_dbl_kind ! conductive heat flux (W/m^2)
         flatn_f(:,:) = -2.0_dbl_kind    ! latent heat flux (W/m^2)
         fsensn_f(:,:) = c0              ! sensible heat flux (W/m^2)
      else
         ! typical spring values
         potT  (:) = 263.15_dbl_kind ! air potential temp (K)
         Tair  (:) = 263.15_dbl_kind ! air temperature  (K)
         Qa    (:) = 0.001_dbl_kind  ! specific humidity (kg/kg)
         swvdr (:) = 25._dbl_kind    ! shortwave radiation (W/m^2)
         swvdf (:) = 25._dbl_kind    ! shortwave radiation (W/m^2)
         swidr (:) = 25._dbl_kind    ! shortwave radiation (W/m^2)
         swidf (:) = 25._dbl_kind    ! shortwave radiation (W/m^2)
         flw   (:) = 230.0_dbl_kind  ! incoming longwave rad (W/m^2)
         frain (:) = c0              ! rainfall rate (kg/m2/s)
         do n = 1, ncat                  ! surface heat flux (W/m^2)
            fsurfn_f(:,n) = fsurfn_d(n)
         enddo
         fcondtopn_f(:,:) = 0.0_dbl_kind ! conductive heat flux (W/m^2)
         flatn_f(:,:) = -1.0_dbl_kind    ! latent heat flux (W/m^2)
         fsensn_f(:,:) = c0              ! sensible heat flux (W/m^2)
      endif !     l_winter

      faero_atm (:,:) = c0           ! aerosol deposition rate (kg/m2/s)
      flux_bio_atm (:,:) = c0        ! zaero and bio deposition rate (kg/m2/s)

      !-----------------------------------------------------------------
      ! fluxes received from ocean
      !-----------------------------------------------------------------

      ss_tltx(:)= c0              ! sea surface tilt (m/m)
      ss_tlty(:)= c0
      uocn  (:) = c0              ! surface ocean currents (m/s)
      vocn  (:) = c0
      frzmlt(:) = c0              ! freezing/melting potential (W/m^2)
      sss   (:) = 34.0_dbl_kind   ! sea surface salinity (ppt)

      do i = 1, nx
         Tf (i) = icepack_liquidus_temperature(sss(i)) ! freezing temp (C)
      enddo

      qdp   (:) = c0              ! deep ocean heat flux (W/m^2)
      hmix  (:) = c20             ! ocean mixed layer depth
      daice_da(:) = c0            ! data assimilation increment rate

      !-----------------------------------------------------------------
      ! fluxes sent to atmosphere
      !-----------------------------------------------------------------

      strairxT(:) = c0            ! wind stress, T grid
      strairyT(:) = c0

      fsens   (:) = c0
      flat    (:) = c0
      fswabs  (:) = c0
      flwout  (:) = -stefan_boltzmann*Tffresh**4   
                        ! in case atm model diagnoses Tsfc from flwout
      evap    (:) = c0
      Tref    (:) = c0
      Qref    (:) = c0
      Uref    (:) = c0
      alvdr   (:) = c0
      alidr   (:) = c0
      alvdf   (:) = c0
      alidf   (:) = c0

      !-----------------------------------------------------------------
      ! fluxes sent to ocean
      !-----------------------------------------------------------------

      strocnxT(:) = c0    ! ice-ocean stress, x-direction (T-cell)
      strocnyT(:) = c0    ! ice-ocean stress, y-direction (T-cell)
      fresh   (:) = c0
      fsalt   (:) = c0
      fhocn   (:) = c0
      fswthru (:) = c0
      fresh_da(:) = c0    ! data assimilation
      fsalt_da(:) = c0
      flux_bio (:,:) = c0 ! bgc
      fnit    (:) = c0
      fsil    (:) = c0
      famm    (:) = c0
      fdmsp   (:) = c0
      fdms    (:) = c0
      fhum    (:) = c0
      fdust   (:) = c0
      falgalN(:,:)= c0
      fdoc   (:,:)= c0
      fdic   (:,:)= c0
      fdon   (:,:)= c0
      ffep   (:,:)= c0
      ffed   (:,:)= c0
      
      !-----------------------------------------------------------------
      ! derived or computed fields
      !-----------------------------------------------------------------

      coszen  (:) = c0            ! Cosine of the zenith angle
!      fsw     (:) = c0            ! shortwave radiation (W/m^2)
      fsw     (:) = swvdr(:) + swvdf(:) + swidr(:) + swidf(:)
      scale_factor(:) = c1        ! shortwave scaling factor 
      wind    (:) = sqrt(uatm(:)**2 &
                           + vatm(:)**2)  ! wind speed, (m/s)
      Cdn_atm(:) = (vonkar/log(zref/iceruf)) &
                     * (vonkar/log(zref/iceruf)) ! atmo drag for RASM

      end subroutine init_coupler_flux

!=======================================================================

! Initialize some fluxes sent to coupler for use by the atm and ocean models
!
! author: Elizabeth C. Hunke, LANL

      subroutine init_flux_atm_ocn

      !-----------------------------------------------------------------
      ! initialize albedo and atmosphere fluxes
      !-----------------------------------------------------------------

      strairxT(:) = c0      ! wind stress, T grid
      strairyT(:) = c0
      ! for rectangular grid tests without thermo
      ! strairxT(:) = 0.15_dbl_kind
      ! strairyT(:) = 0.15_dbl_kind

      fsens   (:) = c0
      flat    (:) = c0
      fswabs  (:) = c0
      flwout  (:) = c0
      evap    (:) = c0
      Tref    (:) = c0
      Qref    (:) = c0
      Uref    (:) = c0

      !-----------------------------------------------------------------
      ! fluxes sent to ocean
      !-----------------------------------------------------------------

      fresh    (:)   = c0
      fsalt    (:)   = c0
      fhocn    (:)   = c0
      fswthru  (:)   = c0
      faero_ocn(:,:) = c0

      end subroutine init_flux_atm_ocn

!=======================================================================

! Initialize thermodynamic fields written to history files.
!
! authors: William H. Lipscomb, LANL
!          Elizabeth C. Hunke, LANL

      subroutine init_history_therm

      use icepack_drv_state, only: aice, vice, trcr
      use icepack_intfc_tracers, only: tr_iage, nt_iage
      use icepack_intfc_shared, only: formdrag
      use icepack_drv_arrays_column, only: &
          hfreebd, hdraft, hridge, distrdg, hkeel, dkeel, lfloe, dfloe, &
          Cdn_atm_skin, Cdn_atm_floe, Cdn_atm_pond, Cdn_atm_rdg, &
          Cdn_ocn_skin, Cdn_ocn_floe, Cdn_ocn_keel, Cdn_atm_ratio, &
          Cdn_atm, Cdn_ocn
      use icepack_drv_constants, only: vonkar,zref,iceruf

      fsurf  (:) = c0
      fcondtop(:)= c0
      congel (:) = c0
      frazil (:) = c0
      snoice (:) = c0
      dsnow  (:) = c0
      meltt  (:) = c0
      melts  (:) = c0
      meltb  (:) = c0
      meltl  (:) = c0
      daidtt (:) = aice(:) ! temporary initial area
      dvidtt (:) = vice(:) ! temporary initial volume
      if (tr_iage) then
         dagedtt(:) = trcr(:,nt_iage) ! temporary initial age
      else
         dagedtt(:) = c0
      endif
      fsurfn    (:,:) = c0
      fcondtopn (:,:) = c0
      flatn     (:,:) = c0
      fsensn    (:,:) = c0
      fpond     (:) = c0
      fresh_ai  (:) = c0
      fsalt_ai  (:) = c0
      fhocn_ai  (:) = c0
      fswthru_ai(:) = c0
      albice (:) = c0
      albsno (:) = c0
      albpnd (:) = c0
      apeff_ai (:) = c0
      snowfrac (:) = c0
      frazil_diag (:) = c0

      ! drag coefficients are computed prior to the atmo_boundary call, 
      ! during the thermodynamics section 
      Cdn_ocn(:) = dragio
      Cdn_atm(:) = (vonkar/log(zref/iceruf)) &
                     * (vonkar/log(zref/iceruf)) ! atmo drag for RASM

      if (formdrag) then
        Cdn_atm_rdg (:) = c0
        Cdn_atm_ratio(:)= c0
        Cdn_atm_floe(:) = c0
        Cdn_atm_pond(:) = c0
        Cdn_atm_skin(:) = c0
        Cdn_ocn_skin(:) = c0
        Cdn_ocn_keel(:) = c0
        Cdn_ocn_floe(:) = c0
        hfreebd     (:) = c0
        hdraft      (:) = c0
        hridge      (:) = c0
        distrdg     (:) = c0
        hkeel       (:) = c0
        dkeel       (:) = c0
        lfloe       (:) = c0
        dfloe       (:) = c0
      endif

      end subroutine init_history_therm

!=======================================================================

! Initialize dynamic fields written to history files.
!
! authors: William H. Lipscomb, LANL
!          Elizabeth C. Hunke, LANL

      subroutine init_history_dyn

      use icepack_drv_state, only: aice, vice, trcr
      use icepack_intfc_tracers, only: tr_iage, nt_iage

      dardg1dt(:) = c0
      dardg2dt(:) = c0
      dvirdgdt(:) = c0
      opening (:) = c0
      daidtd  (:) = aice(:) ! temporary initial area
      dvidtd  (:) = vice(:) ! temporary initial volume
      if (tr_iage) &
         dagedtd (:) = trcr(:,nt_iage) ! temporary initial age
      ardgn   (:,:) = c0
      vrdgn   (:,:) = c0
      krdgn   (:,:) = c1
      aparticn(:,:) = c0
      aredistn(:,:) = c0
      vredistn(:,:) = c0
      dardg1ndt(:,:) = c0
      dardg2ndt(:,:) = c0
      dvirdgndt(:,:) = c0
      araftn   (:,:) = c0
      vraftn   (:,:) = c0
      aredistn (:,:) = c0
      vredistn (:,:) = c0

      end subroutine init_history_dyn

!=======================================================================

! Initialize bgc fields written to history files
!
! authors: Nicole Jeffery, LANL

      subroutine init_history_bgc

      use icepack_constants, only: c0
      use icepack_drv_arrays_column, only: PP_net, grow_net, hbri, &
          ice_bio_net, snow_bio_net, fbio_snoice, fbio_atmice, &
          fzsal, fzsal_g, zfswin 

      PP_net        (:) = c0
      grow_net      (:) = c0
      hbri          (:) = c0
      flux_bio    (:,:) = c0
      flux_bio_ai (:,:) = c0
      ice_bio_net (:,:) = c0
      snow_bio_net(:,:) = c0
      fbio_snoice (:,:) = c0
      fbio_atmice (:,:) = c0
      fzsal         (:) = c0
      fzsal_g       (:) = c0
      zfswin    (:,:,:) = c0
      fnit          (:) = c0
      fsil          (:) = c0
      famm          (:) = c0
      fdmsp         (:) = c0
      fdms          (:) = c0
      fhum          (:) = c0
      fdust         (:) = c0
      falgalN     (:,:) = c0
      fdoc        (:,:) = c0
      fdic        (:,:) = c0
      fdon        (:,:) = c0
      ffep        (:,:) = c0
      ffed        (:,:) = c0

      end subroutine init_history_bgc

!=======================================================================

      end module icepack_drv_flux

!=======================================================================
