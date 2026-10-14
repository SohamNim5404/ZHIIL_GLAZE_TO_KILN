@EndUserText.label: 'Batch Value Help'
@AccessControl.authorizationCheck: #CHECK
@Search.searchable: true

define view entity ZI_KILN_BATCH_VH
  as select distinct from I_Batch
{
  @EndUserText.label: 'Material'
  @Search.defaultSearchElement: true
  key Material,

  @EndUserText.label: 'Batch'
  @Search.defaultSearchElement: true
  key Batch
}
