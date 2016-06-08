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
   
   PROCEDURE delete_vodafone_group_new (
      pi_group_id            IN       VARCHAR2,
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
      v_line           VARCHAR2 (512);
      v_namespace      VARCHAR2 (4000)
         := 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sieb="http://vodafone.com.tr/ServiceCatalog/Business/SiebelServices" xmlns:res="http://vodafone.com.tr/EAI/Common/ResponseCodes"';
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
                                   xmlns:sieb="http://vodafone.com.tr/ServiceCatalog/Business/SiebelServices" 
                                   xmlns:head="http://vodafone.com.tr/EAI/Common/Header" 
                                   xmlns:v1="http://vodafone.com.tr/ServiceCatalog/Business/SubscriberManagement/DeleteVodafoneGroup/v1">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <sieb:DeleteVodafoneGroup_v1>
                      <Header>
                        <head:SourceSystem>ICCB</head:SourceSystem>
                        <head:ReplyExpected>Now</head:ReplyExpected>
                        <head:Credentials>
                          <head:ApplicationId>EAI</head:ApplicationId>
                          <head:User>RP</head:User>
                        </head:Credentials>
                      </Header>
                      <Body>
                        <v1:Request>
                          <v1:GroupId>'
         || pi_group_id
         || '</v1:GroupId>
                        </v1:Request>
                      </Body>
                    </sieb:DeleteVodafoneGroup_v1>
             </soapenv:Body>
          </soapenv:Envelope>';
      v_req := UTL_HTTP.begin_request (v_endpoint_url);
      UTL_HTTP.set_header (v_req, 'User-Agent', 'Mozilla/4.0');
      UTL_HTTP.set_header (v_req, 'Host', v_host || ':' || v_port);
      UTL_HTTP.set_header (v_req, 'Connection', 'close');
      UTL_HTTP.set_header (v_req, 'Content-Type', 'text/xml;charset=UTF-8');
      UTL_HTTP.set_header (v_req, 'SOAPAction', '"DeleteVodafoneGroup_v1"');
      UTL_HTTP.set_header (v_req, 'Content-Length', LENGTH (v_req_xml));
      UTL_HTTP.write_text (v_req, v_req_xml);
      v_resp := UTL_HTTP.get_response (v_req);


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
            ('/soapenv:Envelope/soapenv:Body/sieb:DeleteVodafoneGroup_v1Response/Header/child::node()',
             v_namespace
            );
      DBMS_OUTPUT.put_line (v_resp_xml.getstringval ());
      v_result.responsecode :=
         v_resp_xml.EXTRACT ('/res:ResponseCode/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.responsemsg :=
         v_resp_xml.EXTRACT ('/res:ResponseMsg/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.errorcode :=
         v_resp_xml.EXTRACT ('/res:ErrorCode/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.errordescription :=
         v_resp_xml.EXTRACT ('/res:ErrorDescription/child::node()',
                             v_namespace
                            ).getstringval ();
      v_result.requestid :=
         v_resp_xml.EXTRACT ('/res:RequestId/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.domain :=
         v_resp_xml.EXTRACT ('/res:Domain/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.operation :=
         v_resp_xml.EXTRACT ('/res:Operation/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.VERSION :=
         v_resp_xml.EXTRACT ('/res:Version/child::node()', v_namespace).getstringval
                                                                           ();
      v_result.ATTRIBUTES :=
         v_resp_xml.EXTRACT ('/res:Attributes/child::node()', v_namespace).getstringval
                                                                           ();
      po_error_code := v_result.errorcode;
      po_error_message := v_result.responsemsg;
      po_error_description := v_result.errordescription;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_err := SQLERRM;
         DBMS_OUTPUT.put_line ('Err:' || v_err);
         po_error_code := TO_CHAR (SQLCODE);
         po_error_message := 'Soap Hatasi';
         po_error_description := v_err;
   END;

 
BEGIN
   vi_group_id := '29';
   delete_vodafone_group_new (
      vi_group_id             ,
      vo_error_code          ,
      vo_error_message       ,
      vo_error_description 
   );
   
END;
