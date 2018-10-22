DECLARE 
   vi_group_name                VARCHAR2(50);
   vi_group_id                  VARCHAR2(10);
   vi_parent_group_id           VARCHAR2(10);
   vi_group_start_date          DATE;
   vi_group_end_date            DATE;
   vi_group_type                VARCHAR2(10);
   vi_group_head_number         VARCHAR2(15);
   vi_group_head_number_system  VARCHAR2(1);
   vi_operation_type            VARCHAR2(20);
   vi_discount_percantage       NUMBER(5);
   vo_status_code               VARCHAR2(100);
   vo_error_code                VARCHAR2(4000);
   vo_error_description         VARCHAR2(4000);

   
   PROCEDURE manage_xxx_group (
      pi_group_name                 IN       VARCHAR2,                    -- O
      pi_group_id                   IN       VARCHAR2,                    -- M
      pi_parent_group_id            IN       VARCHAR2,                    -- O
      pi_group_start_date           IN       DATE,                         --M
      pi_group_end_date             IN       DATE,
      pi_group_type                 IN       VARCHAR2,
      pi_group_head_number          IN       VARCHAR2,
      pi_group_head_number_system   IN       VARCHAR2,
      pi_operation_type             IN       VARCHAR2,    -- ADD,DELETE,MODIFY
      pi_discount_percantage        IN       NUMBER,
      po_status_code                OUT      VARCHAR2,                     --M
      po_error_code                 OUT      VARCHAR2,
      po_error_description          OUT      VARCHAR2
   )
   IS
      v_group_start_date   DATE;
      v_css_group_id        NUMBER;
   BEGIN
      po_status_code := '0';
      po_error_code := NULL;
      po_error_description := NULL;

      IF pi_group_id IS NULL
                            --OR pi_group_start_date IS NULL
         OR pi_operation_type IS NULL
      THEN
         po_status_code := '-1';
         po_error_description :=
                   'Group Id , Group Start Date, Operation Type  Zorunludur.';
         RETURN;
      END IF;

      IF pi_operation_type NOT IN ('ADD', 'DELETE', 'MODIFY')
      THEN
         po_status_code := '-1';
         po_error_description :=
                       'Operation Type ADD,DELETE,MODIFY den biri olmalidir.';
         RETURN;
      END IF;

      IF pi_group_start_date IS NULL
      THEN
         SELECT MAX (group_start_date)
           INTO v_group_start_date
           FROM ccb_group
          WHERE group_code = pi_group_id;
      ELSE
         v_group_start_date := pi_group_start_date;
      END IF;

      IF pi_operation_type = 'ADD'
      THEN
         INSERT INTO ccb_group
                     (group_code,                                   --group_id
                      description,                                     --group_name
                      parent_group_code,                            --parent_group_id
                      group_start_date, 
                      group_end_date, 
                      group_type,
                      head_gsm,                                        --group_head_number
                      head_owner_sys,                                  --group_head_number_system
                      direct_discount_ratio,
                      css_cug_id
                     )
              VALUES (pi_group_id, pi_group_name, pi_parent_group_id,
                      v_group_start_date, pi_group_end_date, pi_group_type,
                      pi_group_head_number, pi_group_head_number_system,
                      pi_discount_percantage, TO_NUMBER(pi_group_id)
                     );
      ELSIF pi_operation_type = 'MODIFY'
      THEN
         UPDATE ccb_group
            SET parent_group_code =
                                   NVL (pi_parent_group_id, parent_group_code),
                head_gsm =
                   CASE NVL (NVL (pi_group_head_number_system, head_owner_sys),
                             'C'
                            )
                      WHEN 'C'
                         THEN NVL (pi_group_head_number, head_gsm)
                      ELSE head_gsm
                   END,
                head_owner_sys =
                             NVL (pi_group_head_number_system, head_owner_sys)
          WHERE group_code = pi_group_id
            AND group_start_date = v_group_start_date;
      ELSIF pi_operation_type = 'DELETE'
      THEN
         ccb_savepoint_utility.set_session_variable ('GROUP_INFORMED', 'E');

         UPDATE ccb_group
            SET group_end_date = NVL (pi_group_end_date, SYSDATE)
          WHERE group_code = pi_group_id
            AND group_start_date = v_group_start_date;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         po_status_code := '-1';
         po_error_code := SQLCODE;
         po_error_description := SUBSTR (SQLERRM, 1, 255);
   END manage_xxx_group;
   
BEGIN
   vi_group_name := 'DENEME GRUP';
   vi_group_id := '123456788';
   vi_parent_group_id   := '';
   vi_group_start_date := SYSDATE;
   vi_group_end_date := NULL;
   vi_group_type   := 'G';
   vi_group_head_number := '0';
   vi_group_head_number_system := '';
   vi_operation_type   := 'ADD';
   vi_discount_percantage := '10';   
   
    manage_xxx_group (
      vi_group_name,            
      vi_group_id,                   
      vi_parent_group_id,        
      vi_group_start_date,                       
      vi_group_end_date,     
      vi_group_type,        
      vi_group_head_number,         
      vi_group_head_number_system,   
      vi_operation_type,          
      vi_discount_percantage,       
      vo_status_code,    
      vo_error_code,           
      vo_error_description          
   );
   dbms_output.put_line(vo_status_code);
   dbms_output.put_line(vo_error_code);
   dbms_output.put_line(vo_error_description);   
END;
