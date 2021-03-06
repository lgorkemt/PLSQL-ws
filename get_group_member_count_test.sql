DECLARE 
   vi_group_id           VARCHAR2(100);
   vo_member_count       NUMBER(6);
   vo_error_code         VARCHAR2(100);
   vo_error_message      VARCHAR2(4000);
   vo_error_description  VARCHAR2(4000);
   
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
   
    PROCEDURE group_member_count_from_siebel (
      pi_group_id            IN       VARCHAR2,
      po_member_count        OUT      NUMBER,
      po_error_code          OUT      VARCHAR2,
      po_error_message       OUT      VARCHAR2,
      po_error_description   OUT      VARCHAR2
   )
   IS
      v_endpoint_url   VARCHAR2 (500)
         := ccb.ccb_general_utility.get_parameter_text_value
                                                    ('SIEBEL_GROUP_WA15_URL');
            
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
      v_body_clob      CLOB;
      v_line           VARCHAR2 (2048);
      v_namespace      VARCHAR2 (4000)
         := 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sieb="http://xxx.com.tr/ServiceCatalog/Business/SiebelServices" xmlns:ns="http://xxx.com.tr/ServiceCatalog/Business/SubscriberInquiries/GetGroupMemberTotal/v1"';
         
      v_resp_xml       XMLTYPE;
      v_head_xml       XMLTYPE;
      v_body_xml       XMLTYPE;


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
      v_member_count   VARCHAR2 (100);
      v_member_count_2 VARCHAR2 (100);
      v_body VARCHAR2 (2000);

   BEGIN
      UTL_HTTP.set_transfer_timeout (10);
      v_req_xml :=
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                                      xmlns:sieb="http://xxx.com.tr/ServiceCatalog/Business/SiebelServices" 
                                      xmlns:head="http://xxx.com.tr/EAI/Common/Header" 
                                      xmlns:v1="http://xxx.com.tr/ServiceCatalog/Business/SubscriberInquiries/GetGroupMemberTotal/v1">
                     <soapenv:Header/>
                     <soapenv:Body>
                        <sieb:GetGroupMemberTotal_v1>
                           <Header>
                              <head:RequestId>S003100</head:RequestId>
                              <head:SourceSystem>ICCB</head:SourceSystem>
                              <head:ReplyExpected>Now</head:ReplyExpected>
                              <head:QoS>R</head:QoS>
                              <head:CorrelationId/>
                              <head:Priority>0</head:Priority>                              
                              <head:Credentials>
                                 <head:ApplicationId>Siebel</head:ApplicationId>
                                 <head:User>SADMIN</head:User>
                              </head:Credentials>
                               <head:ProxySystem/>
                               <head:ForceSimulate>false</head:ForceSimulate>
                           </Header>
                           <Body>
                              <v1:Request>    
                                 <v1:GroupID>'
         || pi_group_id
         || '</v1:GroupID>
                              </v1:Request>
                           </Body>
                        </sieb:GetGroupMemberTotal_v1>
                     </soapenv:Body>
                  </soapenv:Envelope>';

      v_req := UTL_HTTP.begin_request (v_endpoint_url);
      UTL_HTTP.set_header (v_req, 'User-Agent', 'Mozilla/4.0');
      UTL_HTTP.set_header (v_req, 'Host', v_host || ':' || v_port);
      --UTL_HTTP.set_header (v_req, 'Host', v_endpoint_url);
      --UTL_HTTP.set_header (v_req, 'Connection', 'close');
      UTL_HTTP.set_header (v_req, 'Content-Type', 'text/xml;charset=UTF-8');
      UTL_HTTP.set_header (v_req, 'SOAPAction', '"GetGroupMemberTotal_v1"');
      UTL_HTTP.set_header (v_req, 'Content-Length', LENGTH (v_req_xml));
      UTL_HTTP.write_text (v_req, v_req_xml);

      v_resp := UTL_HTTP.get_response (v_req);
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

      v_resp_xml := XMLTYPE (v_resp_clob);
      check_fault (v_resp_xml, v_namespace);

      v_head_xml :=
         v_resp_xml.EXTRACT
            ('/soapenv:Envelope/soapenv:Body/GetGroupMemberTotal_v1Response/Header/child::node()',
             v_namespace
            );
      
      IF( v_head_xml.EXTRACT ('/ns:ResponseCode/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN
          v_result.responsecode :=
             v_head_xml.EXTRACT ('/ns:ResponseCode/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval();
      END IF; 
       
      IF( v_head_xml.EXTRACT ('/ns:ResponseMsg/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN          
          v_result.responsemsg :=
             v_head_xml.EXTRACT ('/ns:ResponseMsg/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval();
      END IF;                                                                      

      IF( v_head_xml.EXTRACT ('/ns:ErrorCode/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN           
          v_result.errorcode :=
             v_head_xml.EXTRACT ('/ns:ErrorCode/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval();
      END IF;
 
      IF( v_head_xml.EXTRACT ('/ns:ErrorDescription/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN            
          v_result.errordescription :=
             v_head_xml.EXTRACT ('/ns:ErrorDescription/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval();
      END IF;

      IF( v_head_xml.EXTRACT ('/ns:RequestId/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN        
          v_result.requestid :=
             v_head_xml.EXTRACT ('/ns:RequestId/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval();
      END IF;      
      
         
      IF( v_head_xml.EXTRACT ('/ns:Attributes/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"') IS NOT NULL)
      THEN                                                                      
          v_result.ATTRIBUTES :=
             v_head_xml.EXTRACT ('/ns:Attributes/child::node()', 'xmlns:ns="http://xxx.com.tr/EAI/Common/ResponseCodes"').getstringval(); 
      END IF;      
                                                                          
      po_error_code := v_result.errorcode;
      po_error_message := v_result.responsemsg;
      po_error_description := v_result.errordescription;
     
      --v_namespace := v_namespace ||' xmlns:ns="http://xxx.com.tr/ServiceCatalog/Business/SubscriberInquiries/GetGroupMemberTotal/v1" xmlns:ns0="http://schemas.xmlsoap.org/soap/envelope/"';
      --v_body_xml := v_resp_xml.extract('/soapenv:Envelope/soapenv:Body/sieb:GetGroupMemberTotal_v1Response/Body/child::node()',v_namespace);
      --v_member_count := v_body_xml.extract('/ns:Response/ns:GetGroupMemberTotal/ns:MemberCount/child::node()',v_namespace).getStringVal();

      v_body_xml :=
         v_resp_xml.EXTRACT
            ('/soapenv:Envelope/soapenv:Body/GetGroupMemberTotal_v1Response/Body/child::node()',
             v_namespace
            );
           
      v_body := v_body_xml.getstringval();

      IF(INSTR(v_body ,'<ns:MemberCount>')>0)
      THEN  
            v_member_count := SUBSTR(v_body, INSTR(v_body ,'<ns:MemberCount>') + 16) ;
            v_member_count_2 := SUBSTR(v_member_count, 0,INSTR(v_member_count ,'<') -1);
            v_member_count := v_member_count_2;
      ELSE
          v_member_count := '0';   
      END IF;
           
      po_member_count := TO_NUMBER (v_member_count);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_err := SQLERRM;
         DBMS_OUTPUT.put_line ('Err:' || v_err);
         po_error_code := TO_CHAR (SQLCODE);
         po_error_message := 'Soap Hatasi';
         po_error_description := v_err;
         po_member_count := 0;
   END;

 
BEGIN
   vi_group_id := '10021460';
   group_member_count_from_siebel (
      vi_group_id            ,
      vo_member_count        ,
      vo_error_code          ,
      vo_error_message       ,
      vo_error_description 
   );
   dbms_output.put_line('v_member_count :' || vo_member_count); 
   dbms_output.put_line('vo_error_code' || vo_error_code);
   dbms_output.put_line('vo_error_message' || vo_error_message);
   dbms_output.put_line('vo_error_description' || vo_error_description);  
END;
