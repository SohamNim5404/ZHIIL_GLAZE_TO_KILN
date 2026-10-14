CLASS lhc_kilnheader DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys
                  REQUEST requested_authorizations FOR kilnheader
      RESULT    result.
ENDCLASS.

CLASS lhc_kilnheader IMPLEMENTATION.
  METHOD get_instance_authorizations.
    "Existing authorization method preserved.
    "Authorization logic will be added later.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_kilnitem DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS validateopencycleassignment
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR kilnitem~validateopencycleassignment.

    METHODS validatematerials
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR kilnitem~validatematerials.

    METHODS validateglazedbatchstock
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR kilnitem~validateglazedbatchstock.

    METHODS validateglazedserial
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR kilnitem~validateglazedserial.
ENDCLASS.

CLASS lhc_kilnitem IMPLEMENTATION.

  METHOD validateopencycleassignment.

    READ ENTITIES OF zi_kiln_hdr IN LOCAL MODE
      ENTITY kilnitem
        FIELDS ( uuid parentuuid itemno
                 kilnmaterial kilnbatchno kilnserialno
                 glazedmaterial glazedbatchno glazedserialno )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_read_failed-kilnitem INTO DATA(ls_read_failed).
      "A missing instance has no remaining values to validate.
      "This also covers keys for rows already removed from the draft.
      IF ls_read_failed-%fail-cause = if_abap_behv=>cause-not_found.
        CONTINUE.
      ENDIF.

      "Do not silently ignore other read failures.
      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %fail-cause = ls_read_failed-%fail-cause
      ) TO failed-kilnitem.

      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '001'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-kilnitem.
    ENDLOOP.

    DATA lv_conflict_cycle TYPE ztb_kiln_hdr-kiln_cycle.
    DATA lv_found TYPE abap_bool.
    DATA lv_side TYPE string.
    DATA lv_area TYPE string.
    DATA lv_material TYPE ztb_kiln_itm-kiln_material.
    DATA lv_batch TYPE ztb_kiln_itm-kiln_batch_no.
    DATA lv_serial TYPE ztb_kiln_itm-kiln_serial_no.

    LOOP AT lt_items INTO DATA(ls_item).
      DATA(lv_item_failed) = abap_false.
      SELECT SINGLE kiln_material, kiln_batch_no, kiln_serial_no,
                    glazed_material, glazed_batch_no, glazed_serial_no
        FROM ztb_kiln_itm
        WHERE uuid = @ls_item-uuid
        INTO @DATA(ls_saved).
      DATA(lv_has_saved) = xsdbool( sy-subrc = 0 ).

      DO 2 TIMES.
        DATA(lv_is_kiln) = xsdbool( sy-index = 1 ).

        IF lv_is_kiln = abap_true.
          lv_side = 'Kiln'.
          lv_area = 'KILN_OPEN_ASSIGNMENT'.
          lv_material = ls_item-kilnmaterial.
          lv_batch = ls_item-kilnbatchno.
          lv_serial = ls_item-kilnserialno.
        ELSE.
          lv_side = 'Glazed'.
          lv_area = 'GLAZED_OPEN_ASSIGNMENT'.
          lv_material = ls_item-glazedmaterial.
          lv_batch = ls_item-glazedbatchno.
          lv_serial = ls_item-glazedserialno.
        ENDIF.

        "Clear previous errors even when fields are now blank.
        APPEND VALUE #(
          %tky = ls_item-%tky
          %state_area = lv_area
        ) TO reported-kilnitem.

        IF lv_has_saved = abap_true.
          IF lv_is_kiln = abap_true.
            IF ls_item-kilnmaterial = ls_saved-kiln_material
               AND ls_item-kilnbatchno = ls_saved-kiln_batch_no
               AND ls_item-kilnserialno = ls_saved-kiln_serial_no.
              CONTINUE.
            ENDIF.
          ELSE.
            IF ls_item-glazedmaterial = ls_saved-glazed_material
               AND ls_item-glazedbatchno = ls_saved-glazed_batch_no
               AND ls_item-glazedserialno = ls_saved-glazed_serial_no.
              CONTINUE.
            ENDIF.
          ENDIF.
        ENDIF.

        "Mandatory checks are handled by separate validations.
        IF lv_material IS INITIAL OR lv_batch IS INITIAL
           OR lv_serial IS INITIAL.
          CONTINUE.
        ENDIF.

        CLEAR: lv_conflict_cycle, lv_found.

        "Read active tables only: unsaved drafts do not block reuse.
        "Exclude all items belonging to the current header.
        IF lv_is_kiln = abap_true.
          SELECT SINGLE h~kiln_cycle
            FROM ztb_kiln_itm AS i
            INNER JOIN ztb_kiln_hdr AS h
              ON h~uuid = i~parent_uuid
            WHERE i~kiln_material = @lv_material
              AND i~kiln_batch_no = @lv_batch
              AND i~kiln_serial_no = @lv_serial
              AND h~uuid <> @ls_item-parentuuid
              AND ( h~cycle_status = 'OPEN'
   OR h~cycle_status = 'CLOSED' )
            INTO @lv_conflict_cycle.
          lv_found = xsdbool( sy-subrc = 0 ).
        ELSE.
          SELECT SINGLE h~kiln_cycle
            FROM ztb_kiln_itm AS i
            INNER JOIN ztb_kiln_hdr AS h
              ON h~uuid = i~parent_uuid
            WHERE i~glazed_material = @lv_material
              AND i~glazed_batch_no = @lv_batch
              AND i~glazed_serial_no = @lv_serial
              AND h~uuid <> @ls_item-parentuuid
              AND ( h~cycle_status = 'OPEN'
   OR h~cycle_status = 'CLOSED' )
            INTO @lv_conflict_cycle.
          lv_found = xsdbool( sy-subrc = 0 ).
        ENDIF.

        IF lv_found = abap_true.
          IF lv_item_failed = abap_false.
            APPEND VALUE #( %tky = ls_item-%tky )
              TO failed-kilnitem.
            lv_item_failed = abap_true.
          ENDIF.

          APPEND VALUE #(
            %tky = ls_item-%tky
            %state_area = lv_area
            %path-kilnheader-uuid = ls_item-parentuuid
            %path-kilnheader-%is_draft = ls_item-%is_draft
            %element-kilnmaterial = COND #(
              WHEN lv_is_kiln = abap_true THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %element-kilnbatchno = COND #(
              WHEN lv_is_kiln = abap_true THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %element-kilnserialno = COND #(
              WHEN lv_is_kiln = abap_true THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %element-glazedmaterial = COND #(
              WHEN lv_is_kiln = abap_false THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %element-glazedbatchno = COND #(
              WHEN lv_is_kiln = abap_false THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %element-glazedserialno = COND #(
              WHEN lv_is_kiln = abap_false THEN if_abap_behv=>mk-on
              ELSE if_abap_behv=>mk-off )
            %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '002'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_item-itemno }|
            v2       = lv_side
            v3       = lv_serial
            v4       = |{ lv_conflict_cycle }|
          )
          ) TO reported-kilnitem.

          "Additional context: all six original values are retained across two messages.
          APPEND VALUE #(
            %tky = ls_item-%tky
            %state_area = lv_area
            %path-kilnheader-uuid = ls_item-parentuuid
            %path-kilnheader-%is_draft = ls_item-%is_draft
            %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '003'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_item-itemno }|
            v2       = lv_side
            v3       = lv_material
            v4       = lv_batch
          )
          ) TO reported-kilnitem.
        ENDIF.

      ENDDO.
    ENDLOOP.

  ENDMETHOD.


  METHOD validatematerials.

    READ ENTITIES OF zi_kiln_hdr IN LOCAL MODE
      ENTITY kilnitem
        FIELDS ( parentuuid itemno kilnmaterial glazedmaterial )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_read_failed-kilnitem INTO DATA(ls_read_failed).
      "A missing instance has no remaining values to validate.
      "This also covers keys for rows already removed from the draft.
      IF ls_read_failed-%fail-cause = if_abap_behv=>cause-not_found.
        CONTINUE.
      ENDIF.

      "Do not silently ignore other read failures.
      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %fail-cause = ls_read_failed-%fail-cause
      ) TO failed-kilnitem.

      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '001'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-kilnitem.
    ENDLOOP.

    LOOP AT lt_items INTO DATA(ls_item).

      "Invalidate the previous message when the materials are corrected.
      APPEND VALUE #(
        %tky        = ls_item-%tky
        %state_area = 'MATERIALS_REQUIRED'
      ) TO reported-kilnitem.

      IF ls_item-kilnmaterial IS INITIAL
         AND ls_item-glazedmaterial IS INITIAL.

        APPEND VALUE #( %tky = ls_item-%tky )
          TO failed-kilnitem.

        APPEND VALUE #(
          %tky        = ls_item-%tky
          %state_area = 'MATERIALS_REQUIRED'
          %path-kilnheader-uuid      = ls_item-parentuuid
          %path-kilnheader-%is_draft = ls_item-%is_draft
          %element-kilnmaterial   = if_abap_behv=>mk-on
          %element-glazedmaterial = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '004'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_item-itemno }|
          )
        ) TO reported-kilnitem.

      ENDIF.

            "Clear previous supervisor errors when materials are corrected.
      APPEND VALUE #(
        %tky        = ls_item-%tky
        %state_area = 'GLAZED_SUPERVISOR'
      ) TO reported-kilnitem.

      APPEND VALUE #(
        %tky        = ls_item-%tky
        %state_area = 'KILN_SUPERVISOR'
      ) TO reported-kilnitem.

      DATA(lv_supervisor_failed) = abap_false.

      "GLAZED MATERIAL: supervisor must be ZP6 or YP6.
      IF ls_item-glazedmaterial IS NOT INITIAL.

        SELECT SINGLE product
          FROM i_productplantbasic
          WITH PRIVILEGED ACCESS
          WHERE product = @ls_item-glazedmaterial
            AND ( productionsupervisor = 'ZP6'
               OR productionsupervisor = 'YP6' )
          INTO @DATA(lv_glazed_product).

        IF sy-subrc <> 0.

          lv_supervisor_failed = abap_true.

          APPEND VALUE #(
            %tky        = ls_item-%tky
            %state_area = 'GLAZED_SUPERVISOR'
            %path-kilnheader-uuid      = ls_item-parentuuid
            %path-kilnheader-%is_draft = ls_item-%is_draft
            %element-glazedmaterial   = if_abap_behv=>mk-on
            %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '005'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_item-itemno }|
          )
          ) TO reported-kilnitem.

        ENDIF.
      ENDIF.

      "KILN MATERIAL: supervisor must be ZP7 or YP7.
      IF ls_item-kilnmaterial IS NOT INITIAL.

        SELECT SINGLE product
          FROM i_productplantbasic
          WITH PRIVILEGED ACCESS
          WHERE product = @ls_item-kilnmaterial
            AND ( productionsupervisor = 'ZP7'
               OR productionsupervisor = 'YP7' )
          INTO @DATA(lv_kiln_product).

        IF sy-subrc <> 0.

          lv_supervisor_failed = abap_true.

          APPEND VALUE #(
            %tky        = ls_item-%tky
            %state_area = 'KILN_SUPERVISOR'
            %path-kilnheader-uuid      = ls_item-parentuuid
            %path-kilnheader-%is_draft = ls_item-%is_draft
            %element-kilnmaterial     = if_abap_behv=>mk-on
            %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '006'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_item-itemno }|
          )
          ) TO reported-kilnitem.

        ENDIF.
      ENDIF.

      "Fail this item once, even when both materials are invalid.
      IF lv_supervisor_failed = abap_true.
        APPEND VALUE #( %tky = ls_item-%tky )
          TO failed-kilnitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateglazedbatchstock.

    READ ENTITIES OF zi_kiln_hdr IN LOCAL MODE
      ENTITY kilnitem
        FIELDS ( uuid parentuuid itemno glazedmaterial glazedbatchno )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_read_failed-kilnitem INTO DATA(ls_read_failed).
      "A missing instance has no remaining values to validate.
      "This also covers keys for rows already removed from the draft.
      IF ls_read_failed-%fail-cause = if_abap_behv=>cause-not_found.
        CONTINUE.
      ENDIF.

      "Do not silently ignore other read failures.
      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %fail-cause = ls_read_failed-%fail-cause
      ) TO failed-kilnitem.

      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '001'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-kilnitem.
    ENDLOOP.

    TYPES:
      BEGIN OF ty_stock,
        material TYPE c LENGTH 40,
        batch    TYPE c LENGTH 20,
        quantity TYPE i_stockquantitycurrentvalue_2-matlwrhsstkqtyinmatlbaseunit,
        error    TYPE string,
      END OF ty_stock.

    DATA lt_stock TYPE HASHED TABLE OF ty_stock
      WITH UNIQUE KEY material batch.

    LOOP AT lt_items INTO DATA(ls_item).

      "Invalidate previous state messages for this validation.
      APPEND VALUE #(
        %tky        = ls_item-%tky
        %state_area = 'GLAZED_BATCH_STOCK'
      ) TO reported-kilnitem.

      "Only validate new or changed values against external stock/assignments.
      SELECT SINGLE glazed_material, glazed_batch_no
        FROM ztb_kiln_itm
        WITH PRIVILEGED ACCESS
        WHERE uuid = @ls_item-uuid
        INTO @DATA(ls_saved).
      IF sy-subrc = 0.
        IF ls_item-glazedmaterial = ls_saved-glazed_material
           AND ls_item-glazedbatchno = ls_saved-glazed_batch_no.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA lv_msg_number TYPE symsgno.
      DATA: lv_msg_v1 TYPE symsgv, lv_msg_v2 TYPE symsgv,
            lv_msg_v3 TYPE symsgv, lv_msg_v4 TYPE symsgv.
      CLEAR: lv_msg_number, lv_msg_v1, lv_msg_v2, lv_msg_v3, lv_msg_v4.

      IF ls_item-glazedmaterial IS INITIAL
         OR ls_item-glazedbatchno IS INITIAL.

        lv_msg_number = '007'.
          lv_msg_v1 = |{ ls_item-itemno }|.

      ELSE.

        IF NOT line_exists( lt_stock[
          material = ls_item-glazedmaterial
          batch    = ls_item-glazedbatchno
        ] ).

          DATA(ls_stock) = VALUE ty_stock(
            material = ls_item-glazedmaterial
            batch    = ls_item-glazedbatchno
          ).

          TRY.
              SELECT SUM( matlwrhsstkqtyinmatlbaseunit )
  FROM i_stockquantitycurrentvalue_2(
    p_displaycurrency = 'INR'
  )
  WITH PRIVILEGED ACCESS
  WHERE product = @ls_item-glazedmaterial
    AND batch = @ls_item-glazedbatchno
    AND valuationareatype = '1'
  INTO @ls_stock-quantity.

            CATCH cx_sy_open_sql_db INTO DATA(lx_stock).
              ls_stock-error = lx_stock->get_text( ).
          ENDTRY.

          INSERT ls_stock INTO TABLE lt_stock.
        ENDIF.

        DATA(ls_available) = lt_stock[
          material = ls_item-glazedmaterial
          batch    = ls_item-glazedbatchno
        ].

        IF ls_available-error IS NOT INITIAL.
          lv_msg_number = '008'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedmaterial.
          lv_msg_v3 = ls_item-glazedbatchno.
        ELSEIF ls_available-quantity <= 0.
          lv_msg_number = '009'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedmaterial.
          lv_msg_v3 = ls_item-glazedbatchno.
        ENDIF.

      ENDIF.

      IF lv_msg_number IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-kilnitem.

        APPEND VALUE #(
          %tky        = ls_item-%tky
          %state_area = 'GLAZED_BATCH_STOCK'
          %path-kilnheader-uuid      = ls_item-parentuuid
          %path-kilnheader-%is_draft = ls_item-%is_draft
          %element-glazedmaterial = if_abap_behv=>mk-on
          %element-glazedbatchno  = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = lv_msg_number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_msg_v1
            v2       = lv_msg_v2
            v3       = lv_msg_v3
            v4       = lv_msg_v4
          )
        ) TO reported-kilnitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateglazedserial.

    READ ENTITIES OF zi_kiln_hdr IN LOCAL MODE
      ENTITY kilnitem
        FIELDS (
          uuid parentuuid itemno
          glazedmaterial glazedbatchno glazedserialno
        )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_read_failed-kilnitem INTO DATA(ls_read_failed).
      "A missing instance has no remaining values to validate.
      "This also covers keys for rows already removed from the draft.
      IF ls_read_failed-%fail-cause = if_abap_behv=>cause-not_found.
        CONTINUE.
      ENDIF.

      "Do not silently ignore other read failures.
      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %fail-cause = ls_read_failed-%fail-cause
      ) TO failed-kilnitem.

      APPEND VALUE #(
        %tky = ls_read_failed-%tky
        %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = '001'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-kilnitem.
    ENDLOOP.

    LOOP AT lt_items INTO DATA(ls_item).

      APPEND VALUE #(
        %tky        = ls_item-%tky
        %state_area = 'GLAZED_SERIAL'
      ) TO reported-kilnitem.

      "Only validate new or changed values against external stock/assignments.
      SELECT SINGLE glazed_material, glazed_batch_no, glazed_serial_no
        FROM ztb_kiln_itm
        WITH PRIVILEGED ACCESS
        WHERE uuid = @ls_item-uuid
        INTO @DATA(ls_saved).
      IF sy-subrc = 0.
        IF ls_item-glazedmaterial = ls_saved-glazed_material
           AND ls_item-glazedbatchno = ls_saved-glazed_batch_no
           AND ls_item-glazedserialno = ls_saved-glazed_serial_no.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA lv_msg_number TYPE symsgno.
      DATA: lv_msg_v1 TYPE symsgv, lv_msg_v2 TYPE symsgv,
            lv_msg_v3 TYPE symsgv, lv_msg_v4 TYPE symsgv.
      CLEAR: lv_msg_number, lv_msg_v1, lv_msg_v2, lv_msg_v3, lv_msg_v4.

      IF ls_item-glazedmaterial IS INITIAL
         OR ls_item-glazedserialno IS INITIAL
         OR ls_item-glazedbatchno IS INITIAL.

        lv_msg_number = '010'.
          lv_msg_v1 = |{ ls_item-itemno }|.

      ELSE.

      DATA lv_serial TYPE i_serialnumberstocksegment-serialnumber.

lv_serial = |{ ls_item-glazedserialno ALPHA = IN }|.

        TRY.
        SELECT DISTINCT batch
  FROM i_serialnumberstocksegment
  WITH PRIVILEGED ACCESS
  WHERE material     = @ls_item-glazedmaterial
    AND serialnumber = @lv_serial
  INTO TABLE @DATA(lt_batches).

            IF lt_batches IS INITIAL.
              lv_msg_number = '011'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedserialno.
          lv_msg_v3 = ls_item-glazedmaterial.

            ELSEIF line_exists( lt_batches[
              batch = ls_item-glazedbatchno
            ] ).
              "Matching nonblank batch found: valid assignment.

            ELSEIF lines( lt_batches ) = 1
               AND lt_batches[ 1 ]-batch IS INITIAL.
              lv_msg_number = '012'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedserialno.

            ELSE.
              lv_msg_number = '013'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedserialno.
          lv_msg_v3 = ls_item-glazedbatchno.
            ENDIF.

          CATCH cx_sy_open_sql_db INTO DATA(lx_serial).
            lv_msg_number = '014'.
          lv_msg_v1 = |{ ls_item-itemno }|.
          lv_msg_v2 = ls_item-glazedmaterial.
          lv_msg_v3 = ls_item-glazedserialno.
          lv_msg_v4 = ls_item-glazedbatchno.
        ENDTRY.

      ENDIF.

      IF lv_msg_number IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-kilnitem.

        APPEND VALUE #(
          %tky        = ls_item-%tky
          %state_area = 'GLAZED_SERIAL'
          %path-kilnheader-uuid      = ls_item-parentuuid
          %path-kilnheader-%is_draft = ls_item-%is_draft
          %element-glazedmaterial = if_abap_behv=>mk-on
          %element-glazedbatchno  = if_abap_behv=>mk-on
          %element-glazedserialno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZKILN_MSG'
            number   = lv_msg_number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_msg_v1
            v2       = lv_msg_v2
            v3       = lv_msg_v3
            v4       = lv_msg_v4
          )
        ) TO reported-kilnitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
