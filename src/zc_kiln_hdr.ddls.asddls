@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Kiln Cycle Header'
@Metadata.allowExtensions: true

define root view entity ZC_KILN_HDR
  as projection on ZI_KILN_HDR
{
    key Uuid,
        KilnCycle,
        KilnNo,
       
        Shift,
        StartDate,
        endDate,
        LoadedBy,
        CycleStatus,
        NumberOfItems,

        CreatedBy,
        CreatedAt,
        LastChangedBy,
        LastChangedAt,
        LocalLastChangedAt,

        /* Association */
        _Items : redirected to composition child ZC_KILN_ITM
}
