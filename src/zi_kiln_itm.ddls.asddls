@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Kiln Cycle Item'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_KILN_ITM
  as select from ztb_kiln_itm

  association to parent ZI_KILN_HDR as _Header
    on $projection.ParentUuid = _Header.Uuid

{
    key uuid                  as Uuid,

        parent_uuid           as ParentUuid,
        item_no               as ItemNo,
         loading_date          as LoadingDate,
        kiln_material         as KilnMaterial,
        glazed_material       as GlazedMaterial,
        kiln_batch_no         as KilnBatchNo,
        glazed_batch_no       as GlazedBatchNo,
        kiln_serial_no        as KilnSerialNo,
        glazed_serial_no      as GlazedSerialNo,
        created_by            as CreatedBy,
        created_at            as CreatedAt,
        last_changed_by       as LastChangedBy,
        last_changed_at       as LastChangedAt,
        local_last_changed_at as LocalLastChangedAt,

        _Header
}
