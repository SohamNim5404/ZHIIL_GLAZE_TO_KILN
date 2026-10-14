@EndUserText.label: 'Kiln Material Value Help'
@AccessControl.authorizationCheck: #CHECK
@Search.searchable: true

define view entity ZI_KILN_MAT_VH
  as select from I_ProductText
{
  @EndUserText.label: 'Material'
  @Search.defaultSearchElement: true
  key Product as Material,

  @EndUserText.label: 'Material Description'
  @Search.defaultSearchElement: true
  ProductName as MaterialDescription
}
where Language = $session.system_language
