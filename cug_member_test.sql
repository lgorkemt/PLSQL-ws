DECLARE 
   vi_cug_id VARCHAR2(100);
   vi_subscriber_no    VARCHAR2(100);
   vi_operation_type   VARCHAR2(100);
   vo_error_code        VARCHAR2(100);
   vo_error_message       VARCHAR2(4000);
   vo_error_description   VARCHAR2(4000);
   
   PROCEDURE check_fault (pi_resp IN XMLTYPE, pi_ns IN VARCHAR2)
   IS
      fault_node     XMLTYPE;
      fault_code     VARCHAR2 (256);
      fault_string   VARCHAR2 (32767);
   BEGIN
      fault_node :=
         pi_resp.EXTRACT
               ('/soapenv:Envelope/soapenv:Body/soapenv:Fault/child::node()',
                pi_ns
               );

      IF (fault_node IS NOT NULL)
      THEN
         fault_code :=
            fault_node.EXTRACT ('/faultcode/child::text()', pi_ns).getstringval
                                                                          ();
         fault_string :=
            fault_node.EXTRACT ('/faultstring/child::text()', pi_ns).getstringval
                                                                          ();
         raise_application_error (-20000,
                                  fault_code || ' - ' || fault_string);
      END IF;
   END;
  PROCEDURE manage_cug_member_service (
      pi_cug_id              IN       NUMBER,
      pi_subscriber_no       IN       VARCHAR2,
      pi_operation_type      IN       VARCHAR2,
      po_error_code          OUT      VARCHAR2,
      po_error_message       OUT      VARCHAR2,
      po_error_description   OUT      VARCHAR2
   )
   IS
      v_endpoint_url   VARCHAR2 (500)
         := ccb.ccb_general_utility.get_parameter_text_value
                                                       ('SIEBEL_CUG_WA15_URL');
                                                          --farkli url olacak
      v_host           VARCHAR2 (100)
         := SUBSTR (v_endpoint_url,
                    INSTR (v_endpoint_url, ':') + 3,
                      INSTR (v_endpoint_url, ':', -1)
                    - INSTR (v_endpoint_url, ':')
                    - 3
                   );
      v_port           VARCHAR2 (100)
         := SUBSTR (v_endpoint_url,
                    INSTR (v_endpoint_url, ':', -1) + 1,
                      INSTR (v_endpoint_url, '/', 1, 3)
                    - INSTR (v_endpoint_url, ':', -1)
                    - 1
                   );
      v_err            VARCHAR2 (500);
      v_req            UTL_HTTP.req;
      v_resp           UTL_HTTP.resp;
      v_req_xml        VARCHAR2 (12000);
      v_resp_clob      CLOB;
      v_line           VARCHAR2 (1024);
      v_namespace      VARCHAR2 (4000)
         := 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ccs="http://vodafone.com.tr/ServiceCatalog/Business/CCSServices" xmlns:head="http://vodafone.com.tr/EAI/Common/Header" xmlns:v1="http://vodafone.com.tr/ServiceCatalog/Business/SubscriberManagement/ManageCUGMember/v1" xmlns:ns="http://vodafone.com.tr/EAI/Common/ResponseCodes" xmlns:ns0="http://schemas.xmlsoap.org/soap/envelope/"';
      v_resp_xml       XMLTYPE;

      TYPE resp_type IS RECORD (
         responsecode       VARCHAR2 (200),
         responsemsg        VARCHAR2 (200),
         errorcode          VARCHAR2 (200),
         errordescription   VARCHAR2 (400),
         requestid          VARCHAR2 (200),
         domain             VARCHAR2 (200),
         service            VARCHAR2 (200),
         operation          VARCHAR2 (200),
         VERSION            VARCHAR2 (200),
         ATTRIBUTES         VARCHAR2 (200)
      );

      v_result         resp_type;
   BEGIN
      UTL_HTTP.set_transfer_timeout (60);
      v_req_xml :=
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                                      xmlns:ccs="http://vodafone.com.tr/ServiceCatalog/Business/CCSServices" 
                                      xmlns:head="http://vodafone.com.tr/EAI/Common/Header" 
                                      xmlns:v1="http://vodafone.com.tr/ServiceCatalog/Business/SubscriberManagement/ManageCUGMember/v1">
                     <soapenv:Header/>
                     <soapenv:Body>
                        <ccs:ManageCUGMember_v1>
                           <Header>
                            <head:SourceSystem>Siebel</head:SourceSystem>
                            <head:ReplyExpected>Now</head:ReplyExpected>
                            <head:QoS>R</head:QoS>
                            <head:Credentials>
                                 <head:ApplicationId>1</head:ApplicationId>
                                 <head:User>1</head:User>
                                 <head:Password>1</head:Password>
                            </head:Credentials>
                           </Header>
                           <Body>
                              <v1:Request>
                                 <v1:Community>
									<v1:CugId>'
         || pi_cug_id
         || '</v1:CugId>
                                 <v1:SubscriberNo>'
         || pi_subscriber_no
         || '</v1:SubscriberNo>
                                 <v1:OperationType>'
         || pi_operation_type
         || '</v1:OperationType>
                              </v1:Request>
                           </Body>
                        </ccs:ManageCUGMember_v1>
                     </soapenv:Body>
                  </soapenv:Envelope>';
                  
      utility_error_log ('group_migration_utility.manage_cug_member_service',
                                   'req_xml: ',
                                   'manage_cug_member_service',
                                   NULL,
                                   NULL,
                                   v_req_xml);            
                  
      v_req := UTL_HTTP.begin_request (v_endpoint_url);
      UTL_HTTP.set_header (v_req, 'User-Agent', 'Mozilla/4.0');
      UTL_HTTP.set_header (v_req, 'Host', v_host || ':' || v_port);
      UTL_HTTP.set_header (v_req, 'Content-Type', 'text/xml;charset=UTF-8');
      UTL_HTTP.set_header (v_req, 'SOAPAction', 'ManageCUGMember_v1');
      UTL_HTTP.set_header (v_req, 'Content-Length', LENGTH(v_req_xml));
      UTL_HTTP.write_text (v_req, v_req_xml);
      v_resp := UTL_HTTP.get_response (v_req);
      utility_error_log ('group_migration_utility.manage_cug_member_service',
                                   'status_code: ',
                                   'manage_cug_member_service',
                                   NULL,
                                   NULL,
                                   v_resp.status_code);
      utility_error_log ('group_migration_utility.manage_cug_member_service',
                                   'reason_phrase: ',
                                   'manage_cug_member_service',
                                   NULL,
                                   NULL,
                                   v_resp.reason_phrase);

      /*DBMS_OUTPUT.put_line('Response> status_code: "' || v_resp.status_code || '"');
      DBMS_OUTPUT.put_line('Response> reason_phrase: "' ||v_resp.reason_phrase || '"');
      DBMS_OUTPUT.put_line('Response> http_version: "' ||v_resp.http_version || '"');*/
      BEGIN
         LOOP
            UTL_HTTP.read_line (v_resp, v_line);
            v_resp_clob := v_resp_clob || v_line;
         END LOOP;
      EXCEPTION
         WHEN UTL_HTTP.end_of_body
         THEN
            UTL_HTTP.end_response (v_resp);
      END;

      IF v_req.private_hndl IS NOT NULL
      THEN
         UTL_HTTP.end_request (v_req);
      END IF;

      IF v_resp.private_hndl IS NOT NULL
      THEN
         UTL_HTTP.end_response (v_resp);
      END IF;

      -- dbms_output.put_line(v_resp_clob);
      v_resp_xml := XMLTYPE (v_resp_clob);
      check_fault (v_resp_xml, v_namespace);
      v_resp_xml :=
         v_resp_xml.EXTRACT
            ('/soapenv:Envelope/soapenv:Body/ManageCUGMember_v1Response/Header/child::node()',
             v_namespace
            );
      
      IF( v_resp_xml.EXTRACT ('/ns:ResponseCode/child::node()', v_namespace) IS NOT NULL)
      THEN
         v_result.responsecode :=
            v_resp_xml.EXTRACT ('/ns:ResponseCode/child::node()', v_namespace).getstringval();
      END IF;
      
      IF( v_resp_xml.EXTRACT ('/ns:ResponseMsg/child::node()', v_namespace) IS NOT NULL)
      THEN
          v_result.responsemsg :=
             v_resp_xml.EXTRACT ('/ns:ResponseMsg/child::node()', v_namespace).getstringval();
      END IF;  
      
      IF( v_resp_xml.EXTRACT ('/ns:ErrorCode/child::node()', v_namespace) IS NOT NULL)
      THEN                                                  
          v_result.errorcode :=
             v_resp_xml.EXTRACT ('/ns:ErrorCode/child::node()', v_namespace).getstringval();
      END IF;
 
      IF( v_resp_xml.EXTRACT ('/ns:ErrorDescription/child::node()', v_namespace) IS NOT NULL)
      THEN       
          v_result.errordescription :=
             v_resp_xml.EXTRACT ('/ns:ErrorDescription/child::node()', v_namespace).getstringval();
      END IF;  
      
      IF( v_resp_xml.EXTRACT ('/ns:RequestId/child::node()', v_namespace) IS NOT NULL)
      THEN  
          v_result.requestid :=
             v_resp_xml.EXTRACT ('/ns:RequestId/child::node()', v_namespace).getstringval();
      END IF;                                                    
      
      IF( v_resp_xml.EXTRACT ('/ns:Attributes/child::node()', v_namespace) IS NOT NULL)
      THEN 
          v_result.ATTRIBUTES :=
             v_resp_xml.EXTRACT ('/ns:Attributes/child::node()', v_namespace).getstringval();
      END IF;  
                                                               
      po_error_code := v_result.errorcode;
      po_error_message := v_result.responsemsg;
      po_error_description := v_result.errordescription;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_err := SQLERRM;
         --dbms_output.put_line('Err:'||v_err);
         po_error_code := TO_CHAR (SQLCODE);
         po_error_message := 'Soap Hatasi';
         po_error_description := v_err;
   END;
   
   PROCEDURE manage_cug_member (
      pi_cug_id              IN       VARCHAR2,
      pi_subscriber_no       IN       VARCHAR2,
      pi_operation_type      IN       VARCHAR2,
      pi_css_cug_id    		 IN       NUMBER,	 	  
      po_error_code          OUT      VARCHAR2,
      po_error_message       OUT      VARCHAR2,
      po_error_description   OUT      VARCHAR2
   )
   IS
      CURSOR c1
      IS
         SELECT parent_group_code
           FROM ccb_group
          WHERE group_code = pi_cug_id;

      v_parent_group_code   ccb_group.parent_group_code%TYPE;
	  v_css_cug_id 			ccb_group.css_cug_id%TYPE;	  
   BEGIN
      OPEN c1;

      FETCH c1
       INTO v_parent_group_code;

      CLOSE c1;

      IF v_parent_group_code IS NOT NULL
      THEN
	  	
		SELECT css_cug_id
		  INTO v_css_cug_id
		  FROM ccb_group
         WHERE group_code = v_parent_group_code;
			
		 IF v_css_cug_id = 0 THEN
			v_css_cug_id := -1;
		 END IF;
		 
         manage_cug_member_service (v_css_cug_id,
                                    pi_subscriber_no,
                                    pi_operation_type,
                                    po_error_code,
                                    po_error_message,
                                    po_error_description
                                   );
      END IF;

      manage_cug_member_service (pi_css_cug_id,
                                 pi_subscriber_no,
                                 pi_operation_type,
                                 po_error_code,
                                 po_error_message,
                                 po_error_description
                                );
   END;
   
BEGIN
   vi_cug_id := '21011620';
   vi_subscriber_no := '5431087898';
   vi_operation_type   := 'Delete';
   manage_cug_member (
      vi_cug_id              ,
      vi_subscriber_no       ,
      vi_operation_type      ,
	  vi_cug_id		         ,
      vo_error_code          ,
      vo_error_message       ,
      vo_error_description 
   );
   dbms_output.put_line(vo_error_code);
   dbms_output.put_line(vo_error_message);
   dbms_output.put_line(vo_error_description);   
END;
