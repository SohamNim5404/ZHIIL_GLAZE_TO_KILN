@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Kiln Cycle Item'
@Metadata.allowExtensions: true
@UI.createHidden: true


define view entity ZC_KILN_ITM
  as projection on ZI_KILN_ITM
{
    key Uuid,
        ParentUuid,
        ItemNo,
        LoadingDate,
        KilnMaterial,
        GlazedMaterial,
        KilnBatchNo,
        GlazedBatchNo,
        KilnSerialNo,
        GlazedSerialNo,
        CreatedBy,
        CreatedAt,
        LastChangedBy,
        LastChangedAt,
        LocalLastChangedAt,

        /* Association */
        _Header : redirected to parent ZC_KILN_HDR
}
