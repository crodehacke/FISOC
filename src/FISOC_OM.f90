MODULE FISOC_OM_MOD
  
  USE ESMF
  USE FISOC_utils_MOD
  USE FISOC_OM_Wrapper
    
  IMPLICIT NONE
  
  PRIVATE
  
  PUBLIC FISOC_OM_register
    
CONTAINS
  
  SUBROUTINE FISOC_OM_register(FISOC_OM, rc)
    
    TYPE(ESMF_GridComp)  :: FISOC_OM
    INTEGER, INTENT(OUT) :: rc
    
    rc = ESMF_FAILURE

    CALL ESMF_GridCompSetEntryPoint(FISOC_OM, ESMF_METHOD_INITIALIZE, &
         userRoutine=FISOC_OM_init_phase1, phase=1, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_GridCompSetEntryPoint(FISOC_OM, ESMF_METHOD_INITIALIZE, &
         userRoutine=FISOC_OM_init_phase2, phase=2, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    
    CALL ESMF_GridCompSetEntryPoint(FISOC_OM, ESMF_METHOD_RUN, &
         userRoutine=FISOC_OM_run, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    
    CALL ESMF_GridCompSetEntryPoint(FISOC_OM, ESMF_METHOD_FINALIZE, &
         userRoutine=FISOC_OM_finalise, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    rc = ESMF_SUCCESS
 
  END SUBROUTINE FISOC_OM_register


  !------------------------------------------------------------------------------
  SUBROUTINE FISOC_OM_init_phase1(FISOC_OM, OM_ImpSt, OM_ExpSt, FISOC_clock, rc)
    TYPE(ESMF_GridComp)        :: FISOC_OM
    TYPE(ESMF_State)           :: OM_ImpSt, OM_ExpSt 
    TYPE(ESMF_Clock)           :: FISOC_clock
    INTEGER, INTENT(OUT)       :: rc

    TYPE(ESMF_config)          :: FISOC_config
    TYPE(ESMF_grid)            :: OM_grid
    TYPE(ESMF_fieldBundle)     :: OM_ExpFB,OM_ExpFBcum
    TYPE(ESMF_VM)              :: VM
    INTEGER                    :: mpic, mpic2, ierr, localPet

    CHARACTER(len=ESMF_MAXSTR) :: label
    CHARACTER(len=ESMF_MAXSTR),ALLOCATABLE :: OM_ReqVarList(:)


    rc = ESMF_FAILURE

    msg = "OM initialise started"
    CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
       line=__LINE__, file=__FILE__, rc=rc)

    ! get information from the OM gridded component.  vm is virtual machine.
    CALL ESMF_GridCompGet(FISOC_OM, config=FISOC_config, vm=vm, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    !-------------------------------------------------------------------------------
    ! Get the parallel context, specifically the mpi communicator, for the OM to 
    ! use.
    ! The returned MPI communicator spans the same MPI processes that the VM
    ! is defined on.
    CALL ESMF_VMGet(vm, localPet=localPet, mpiCommunicator=mpic, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    ! Duplicate the MPI communicator not to interfere with ESMF communications.
    ! The duplicate MPI communicator can be used in any MPI call in the user
    ! code. 
#ifdef FISOC_MPI
    CALL MPI_Comm_dup(mpic, mpic2, ierr)
#else
    mpic2 = -999
#endif
    
    ! create empty field bundle to be populated my model-specific code.
    OM_ExpFB = ESMF_FieldBundleCreate(name='OM export fields', rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    OM_ExpFBcum = ESMF_FieldBundleCreate(name='OM export field cumulator', rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    ! model-specific initialisation
#ifdef FISOC_MPI
    CALL FISOC_OM_Wrapper_Init_Phase1(OM_ExpFB,OM_grid,FISOC_config,mpic2,vm,localPet,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
#else
    CALL FISOC_OM_Wrapper_Init_Phase1(OM_ExpFB,OM_grid,FISOC_config,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
#endif

    CALL FISOC_initCumulatorFB(OM_ExpFB,OM_ExpFBcum,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL FISOC_zeroBundle(OM_ExpFBcum,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    ! we only add the OM field bundle to the import state as a way of letting the coupler get hold of the 
    ! grid.  There must be a better way to do this.
    CALL ESMF_StateAdd(OM_ImpSt, (/OM_ExpFB/), rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_StateAdd(OM_ExpSt, (/OM_ExpFB/), rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_StateAdd(OM_ExpSt, (/OM_ExpFBcum/), rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    msg = "OM initialise phase 1 complete"
    CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
       line=__LINE__, file=__FILE__, rc=rc)

    rc = ESMF_SUCCESS

  END SUBROUTINE FISOC_OM_init_phase1
  
  !------------------------------------------------------------------------------
  SUBROUTINE FISOC_OM_init_phase2(FISOC_OM, OM_ImpSt, OM_ExpSt, FISOC_clock, rc)
    TYPE(ESMF_GridComp)    :: FISOC_OM
    TYPE(ESMF_State)       :: OM_ImpSt, OM_ExpSt 
    TYPE(ESMF_Clock)       :: FISOC_clock
    INTEGER, INTENT(OUT)   :: rc

    INTEGER                :: localPet
    TYPE(ESMF_VM)          :: vm
    TYPE(ESMF_config)      :: FISOC_config
    TYPE(ESMF_fieldbundle) :: OM_ImpFB

    rc = ESMF_FAILURE

    CALL ESMF_GridCompGet(FISOC_OM, config=FISOC_config, vm=vm, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_VMGet(vm, localPet=localPet, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_StateGet(OM_ImpSt, "OM import fields", OM_ImpFB, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
    
    CALL FISOC_OM_Wrapper_Init_Phase2(OM_ImpFB,FISOC_config,localPet,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    msg = "OM initialise phase 2 (allows the OM access to the ISM initial state) "
    CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
       line=__LINE__, file=__FILE__, rc=rc)

    rc = ESMF_SUCCESS

  END SUBROUTINE FISOC_OM_init_phase2
  
  !------------------------------------------------------------------------------
  SUBROUTINE FISOC_OM_run(FISOC_OM, OM_ImpSt, OM_ExpSt, FISOC_clock, rc)
    TYPE(ESMF_GridComp)        :: FISOC_OM
    TYPE(ESMF_State)           :: OM_ImpSt, OM_ExpSt 
    TYPE(ESMF_Clock)           :: FISOC_clock
    INTEGER, INTENT(OUT)       :: rc

    TYPE(ESMF_FileStatus_Flag) :: NC_status
    CHARACTER(len=ESMF_MAXSTR) :: OutputFileName 
    TYPE(ESMF_VM)              :: vm
    INTEGER(ESMF_KIND_I8)      :: advanceCount
    INTEGER                    :: localPet,advanceCountInt4,OM_outputCount = 1
    TYPE(ESMF_fieldbundle)     :: OM_ImpFB, OM_ExpFB, OM_ExpFBcum
    TYPE(ESMF_config)          :: FISOC_config
    TYPE(ESMF_Alarm)           :: alarm_OM_output, alarm_ISM, alarm_ISM_exportAvailable
    LOGICAL                    :: verbose_coupling, OM_writeNetcdf

    SAVE OM_outputCount

    rc = ESMF_FAILURE
   
    CALL ESMF_GridCompGet(FISOC_OM, config=FISOC_config, vm=vm, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_VMGet(vm, localPet=localPet, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_ConfigGetAttribute(FISOC_config, verbose_coupling, label='verbose_coupling:', rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_ConfigGetAttribute(FISOC_config,  OM_writeNetcdf, label='OM_writeNetcdf:', rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) THEN
       msg="WARNING: OM_writeNetcdf not found in FISOC_config.rc, not writing to NetCDF"
       OM_writeNetcdf = .FALSE.
       CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
            line=__LINE__, file=__FILE__, rc=rc)
    END IF

    CALL ESMF_ClockGetAlarm(FISOC_clock, "alarm_ISM", alarm_ISM, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_ClockGetAlarm(FISOC_clock, "alarm_ISM_exportAvailable", alarm_ISM_exportAvailable, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_ClockGetAlarm(FISOC_clock, "alarm_OM_output", alarm_OM_output, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)


    ! Decide how to call OM run wrapper depending on relevant alarms
    OM_output: IF (ESMF_AlarmIsRinging(alarm_OM_output, rc=rc)) THEN
       
       CALL ESMF_StateGet(OM_ExpSt, "OM export fields", OM_ExpFB, rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

       IF (ESMF_AlarmIsRinging(alarm_ISM_exportAvailable, rc=rc)) THEN

          CALL ESMF_StateGet(OM_ImpSt, "OM import fields", OM_ImpFB, rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
          
          CALL FISOC_OM_Wrapper_Run(FISOC_config,localPet,OM_ExpFB=OM_ExpFB,OM_ImpFB=OM_ImpFB,rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
          
       ELSE
          CALL FISOC_OM_Wrapper_Run(FISOC_config,localPet,OM_ExpFB=OM_ExpFB,rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)              
       END IF
       
!       print*,"NETCDF ",ESMF_IO_NETCDF_PRESENT 
!       print*,"parallel NETCDF ",ESMF_IO_PNETCDF_PRESENT 

       ! "AdvanceCount" gives the number of timesteps.  Use it to make NetCDF filename.
       CALL ESMF_ClockGet(FISOC_clock, advanceCount=advanceCount, rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
!       advanceCountInt4 = advanceCount
       WRITE (OutputFileName, "(A14,I0,A3)") "FISOC_OM_out_t", advanceCount, ".nc"

       writeNC: IF (OM_writeNetcdf) THEN
          CALL ESMF_VMBarrier(vm, rc=rc)
          msg = "Writing NetCDF output from FISOC on ocean grid"
          CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
               line=__LINE__, file=__FILE__, rc=rc)
          NCpresent: IF (ESMF_IO_NETCDF_PRESENT) THEN
             NC_status=ESMF_FILESTATUS_REPLACE
             CALL  ESMF_FieldBundleWrite(OM_ExpFB, TRIM(OutputFileName),  overwrite=.FALSE., & 
                  status=NC_status, iofmt=ESMF_IOFMT_NETCDF, rc=rc)
             IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
                  line=__LINE__, file=__FILE__)) &
                     CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
             OM_outputCount = OM_outputCount + 1
          ELSE
             msg = "ERROR: trying to write NetCDF output but NetCDF "// &
                  "not present in this ESMF build."
             CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
                  line=__LINE__, file=__FILE__, rc=rc)
             CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
          END IF NCpresent
       END IF writeNC

    ELSE
       
       IF (ESMF_AlarmIsRinging(alarm_ISM_exportAvailable, rc=rc)) THEN
          
          CALL ESMF_StateGet(OM_ImpSt, "OM import fields", OM_ImpFB, rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
          
          CALL FISOC_OM_Wrapper_Run(FISOC_config,localPet,OM_ImpFB=OM_ImpFB,rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
          
       ELSE
          CALL FISOC_OM_Wrapper_Run(FISOC_config,localPet,rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)              
          
       END IF
       
    END IF OM_output
    
    ! cumulate the outputs if we have new outputs from the OM this step
    OM_cumulate: IF (ESMF_AlarmIsRinging(alarm_OM_output)) THEN
       CALL ESMF_StateGet(OM_ExpSt, "OM export field cumulator", OM_ExpFBcum, rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
       
       CALL FISOC_cumulateFB(OM_ExpFB,OM_ExpFBcum,rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    

       ! ...and process the cumulated outputs if this is an ISM step
       IF (ESMF_AlarmIsRinging(alarm_ISM)) THEN
          CALL FISOC_processCumulator(OM_ExpFB,OM_ExpFBcum,FISOC_config,rc=rc)
          IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) &
               CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    
       END IF
       
    END IF OM_cumulate
    
    rc = ESMF_SUCCESS

  END SUBROUTINE FISOC_OM_run
  
  !------------------------------------------------------------------------------
  SUBROUTINE FISOC_OM_finalise(FISOC_OM, OM_ImpSt, OM_ExpSt, FISOC_clock, rc)
    TYPE(ESMF_GridComp)    :: FISOC_OM
    TYPE(ESMF_State)       :: OM_ImpSt, OM_ExpSt 
    TYPE(ESMF_Clock)       :: FISOC_clock
    INTEGER, INTENT(OUT)   :: rc

    TYPE(ESMF_VM)                :: vm
    TYPE(ESMF_config)            :: FISOC_config
    TYPE(ESMF_fieldbundle)       :: OM_ImpFB, OM_ExpFB
    INTEGER                      :: FieldCount,ii, localPet
    TYPE(ESMF_field),ALLOCATABLE :: FieldList(:)
    TYPE(ESMF_grid)              :: OM_grid
    
    rc = ESMF_FAILURE


    msg = "OM finalise: destroy fields, bundles and grid"
    CALL ESMF_LogWrite(msg, logmsgFlag=ESMF_LOGMSG_INFO, &
       line=__LINE__, file=__FILE__, rc=rc)

    CALL ESMF_GridCompGet(FISOC_OM, config=FISOC_config, vm=vm, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_VMGet(vm, localPet=localPet, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_StateGet(OM_ImpSt, "OM import fields", OM_ImpFB, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    

    ! ...how many fields?...
    CALL ESMF_FieldBundleGet(OM_ImpFB, fieldCount=FieldCount, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    ! ... get list of fields from bundle.
    ALLOCATE(FieldList(FieldCount))
    CALL ESMF_FieldBundleGet(OM_ImpFB, fieldCount=FieldCount, fieldList=FieldList,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    CALL ESMF_FieldGet(FieldList(1), grid=OM_grid, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    CALL ESMF_GridDestroy(OM_grid,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    DO ii = 1,FieldCount
       CALL ESMF_FieldDestroy(FieldList(ii), rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    END DO

    DEALLOCATE(FieldList)

    CALL ESMF_FieldBundleDestroy(OM_ImpFB, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    

    CALL ESMF_StateGet(OM_ExpSt, "OM export fields", OM_ExpFB, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)    

    ! ...how many fields?...
    CALL ESMF_FieldBundleGet(OM_ExpFB, fieldCount=FieldCount, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    ! ... get list of fields from bundle.
    ALLOCATE(FieldList(FieldCount))
    CALL ESMF_FieldBundleGet(OM_ExpFB, fieldCount=FieldCount, fieldList=FieldList,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    DO ii = 1,FieldCount
       CALL ESMF_FieldDestroy(FieldList(ii), rc=rc)
       IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) &
            CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    END DO

    DEALLOCATE(FieldList)

    CALL ESMF_FieldBundleDestroy(OM_ExpFB, rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)
    
    CALL FISOC_OM_Wrapper_Finalize(FISOC_config,localPet,rc=rc)
    IF (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, file=__FILE__)) &
         CALL ESMF_Finalize(endflag=ESMF_END_ABORT)

    rc = ESMF_SUCCESS

  END SUBROUTINE FISOC_OM_finalise  

END MODULE FISOC_OM_MOD
