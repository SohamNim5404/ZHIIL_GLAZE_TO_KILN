@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift Value Help'

@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZCYCLE_STAT_DD
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE(
                   p_domain_name: 'ZDOM_STATS'
                 ) as DomainValue

    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T(
                      p_domain_name: 'ZDOM_STATS'
                    ) as DomainText

      on  DomainText.domain_name    = DomainValue.domain_name
      and DomainText.value_position = DomainValue.value_position
      and DomainText.language       = $session.system_language

{
      @ObjectModel.text.element: [ 'cycle_status_TEXT' ]
      @UI.textArrangement: #TEXT_ONLY

  key DomainValue.value_low as cycle_status,

      @Semantics.text: true
      DomainText.text        as cycle_status_TEXT
}
