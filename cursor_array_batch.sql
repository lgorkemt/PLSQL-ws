-- Searches subscribers of a customer and deletes unrelated records of the subscriber in the CCB_CUSTOMER_SUBSCRIBER_ADDRES table
DECLARE
    v_customer_id     CCB_CUSTOMER.CUSTOMER_ID%TYPE;
    v_gsm_no          CCB_SUBSCRIBER.GSM_NO%TYPE;
    v_start_date      CCB_CUSTOMER_SUBSCRIBER_ADDRES.START_DATE%TYPE;
    v_addresstype     CCB_CUSTOMER_SUBSCRIBER_ADDRES.ADDRESSTYPE%TYPE;
    v_seq             CCB_CUSTOMER_SUBSCRIBER_ADDRES.SEQ%TYPE;
    v_exists          BOOLEAN;
    v_err             VARCHAR2(200);

    CURSOR customer_cursor IS
       SELECT distinct(C.CUSTOMER_ID)
       FROM CCB_CUSTOMER C
       INNER JOIN CCB_CUSTOMER_INFO CI
        ON C.CUSTOMER_ID = CI.CUSTOMER_ID
       WHERE CI.INFO_TYPE = 'SPLITTED_CUSTOMER_ID';
           
     CURSOR subscriber_address_cursor IS 
        SELECT  gsm_no,start_date, addresstype, customer_id, seq
            FROM CCB_CUSTOMER_SUBSCRIBER_ADDRES
            WHERE customer_id = v_customer_id;
           
     v_customer_row    customer_cursor%ROWTYPE;
     v_subscriber_adress_row  subscriber_address_cursor%ROWTYPE;
     
     TYPE ccb_subs_rec IS RECORD(
        gsm_no CCB_SUBSCRIBER.GSM_NO%TYPE,
        start_date CCB_SUBSCRIBER.START_DATE%TYPE
     );
    
    TYPE ccb_subs_table    IS TABLE OF ccb_subs_rec;
    v_gsm_arr ccb_subs_table;
    
    -- check if a particular gsm_no and start date exist in subscriber table
    FUNCTION CHECK_GSMNO_IS_VALID(pi_gsm_no IN VARCHAR2, pi_start_date IN DATE, pi_gsm_arr IN ccb_subs_table)
        RETURN BOOLEAN
    IS
        v_exists2 BOOLEAN;
    BEGIN
        v_exists2 := FALSE; 
        FOR i IN 1..pi_gsm_arr.COUNT LOOP
            IF pi_gsm_arr(i).gsm_no = pi_gsm_no AND to_char(pi_gsm_arr(i).start_date, 'dd/mm/yyyy') = to_char(pi_start_date, 'dd/mm/yyyy')  THEN
                v_exists2 := TRUE;
            END IF;
        END LOOP;
        RETURN v_exists2;
    END CHECK_GSMNO_IS_VALID;

BEGIN
  -- Iterate customers
  FOR v_customer_row IN customer_cursor LOOP
    v_customer_id:=v_customer_row.customer_id;

    -- Take customers subscribers       
    SELECT  S.GSM_NO, S.START_DATE
        BULK COLLECT INTO v_gsm_arr  
    FROM CCB_CUSTOMER C, CCB_SUBSCRIBER S 
    WHERE C.CUSTOMER_ID = v_customer_id AND C.CUSTOMER_ID = S.CUSTOMER_ID;
	
    -- iterate CCB_CUSTOMER_SUBSCRIBER_ADDRES records. In case of an unrelated record, record is deleted.
    FOR  v_subscriber_adress_row IN subscriber_address_cursor LOOP
		v_exists := CHECK_GSMNO_IS_VALID(v_subscriber_adress_row.gsm_no, v_subscriber_adress_row.start_date, v_gsm_arr);
		-- delete unrelated record
        IF(v_exists = FALSE) THEN
            v_gsm_no := v_subscriber_adress_row.gsm_no;
            v_seq := v_subscriber_adress_row.seq;
            v_addresstype  := v_subscriber_adress_row.addresstype;
            v_start_date  := v_subscriber_adress_row.start_date;
            DELETE FROM  CCB_CUSTOMER_SUBSCRIBER_ADDRES
            WHERE CUSTOMER_ID = v_customer_id AND GSM_NO = v_gsm_no AND SEQ = v_seq AND  START_DATE = v_start_date AND ADDRESSTYPE = v_addresstype ;
			
            --dbms_output.put_line('deleted -> customer_id, gsm_no,start_date,addresstype, seq ' ||  v_customer_id || ',' || v_gsm_no || ',' || v_start_date || ',' || v_addresstype || ',' || v_seq );  
        END IF; 
    END LOOP;  
    
  END LOOP;
EXCEPTION 
  WHEN OTHERS THEN
    v_err := SQLERRM;
    dbms_output.put_line('Err:' || v_err);
END;
