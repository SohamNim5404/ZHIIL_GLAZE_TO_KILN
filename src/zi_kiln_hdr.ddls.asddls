@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Kiln Cycle Header'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_KILN_HDR
  as select from ztb_kiln_hdr

  composition [0..*] of ZI_KILN_ITM as _Items

{
    key uuid                  as Uuid,

        kiln_cycle            as KilnCycle,
        @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'Zkiln_CEN_VH',
          element: 'kiln_no'
        }
      }]
        kiln_no               as KilnNo,
       
        @Consumption.valueHelpDefinition: [
      {
      entity: {
      name: 'ZSHIFT_DD',
      element: 'Shift'
      }
      }
      ]
        shift                 as Shift,
        start_date           as StartDate,
        end_date           as endDate,
        loaded_by             as LoadedBy,
               @Consumption.valueHelpDefinition: [
      {
      entity: {
      name: 'ZCYCLE_STAT_DD',
      element: 'cycle_status'
      }
      }
      ]
        cycle_status          as CycleStatus,
        number_of_items       as NumberOfItems,

        created_by            as CreatedBy,
        created_at            as CreatedAt,
        last_changed_by       as LastChangedBy,
        last_changed_at       as LastChangedAt,
        local_last_changed_at as LocalLastChangedAt,

        _Items
}
