--SELECT utl_http.request('http://IBMCRM06:8088/mockHTTPBindingBinding?wsdl') FROM DUAL;
DECLARE 
   pi_group_code VARCHAR2(100);
   v_endpoint_url VARCHAR2(500):= 'http://IBMCRM06:8088/mockHTTPBindingBinding'; -- PARAMETRIK
   v_host VARCHAR2(100) := SUBSTR(v_endpoint_url,INSTR(v_endpoint_url,':')+3,INSTR(v_endpoint_url,':',-1)-INSTR(v_endpoint_url,':')-3);
   v_port VARCHAR2(100) := SUBSTR(v_endpoint_url,INSTR(v_endpoint_url,':',-1)+1,INSTR(v_endpoint_url,'/',-1)-INSTR(v_endpoint_url,':',-1)-1); 
   v_err VARCHAR2(500);
   v_req  UTL_HTTP.req;
   v_resp UTL_HTTP.resp;
   v_req_xml VARCHAR2(12000); 
   v_resp_clob CLOB;
   --v_buffer_size    NUMBER(10) := 512;
   v_line           VARCHAR2(512);
  -- v_line_size      NUMBER(10) := 256;
   v_lines_count    NUMBER(10) := 20;
--   v_raw_data       RAW(512);
 --  v_req_msg        VARCHAR2(512);
   v_namespace      VARCHAR2(4000) := 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sieb="http://vodafone.com.tr/ServiceCatalog/Business/SiebelServices" xmlns:res="http://vodafone.com.tr/EAI/Common/ResponseCodes"';
   v_resp_xml       XMLTYPE;
   TYPE RESP_TYPE IS RECORD (
      ResponseCode VARCHAR2(200),
      ResponseMsg  VARCHAR2(200),
      ErrorCode    VARCHAR2(200),
      ErrorDescription VARCHAR2(400),
      RequestId VARCHAR2(200),
      Domain    VARCHAR2(200),
      Service   VARCHAR2(200),
      Operation VARCHAR2(200),
      Version   VARCHAR2(200),
      Attributes VARCHAR2(200)
   );
   v_result RESP_TYPE;
     PROCEDURE check_fault(pi_resp IN XMLTYPE,pi_ns IN VARCHAR2) IS
     fault_node     XMLTYPE;
     fault_code     VARCHAR2 (256);
     fault_string   VARCHAR2 (32767);
  BEGIN
    fault_node := pi_resp.extract('/soapenv:Envelope/soapenv:Body/soapenv:Fault/child::node()',pi_ns);
    IF (fault_node IS NOT NULL)
    THEN
      fault_code   := fault_node.extract ('/faultcode/child::text()', pi_ns).getstringval ();
      fault_string := fault_node.extract ('/faultstring/child::text()', pi_ns).getstringval ();
      raise_application_error (-20000, fault_code || ' - ' || fault_string);
    END IF;
  END;
BEGIN
    UTL_HTTP.set_transfer_timeout(60);
    dbms_output.put_line('Host:'||v_host);
    dbms_output.put_line('Port:'||v_port);
    
    v_req_xml :='<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
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
                          <v1:GroupId>'||pi_group_code||'</v1:GroupId>
                        </v1:Request>
                      </Body>
                    </sieb:DeleteVodafoneGroup_v1>
             </soapenv:Body>
          </soapenv:Envelope>';
       v_req := UTL_HTTP.begin_request(v_endpoint_url,
                                           'POST',
                                           'HTTP/1.1');
      
    UTL_HTTP.set_header(v_req, 'User-Agent', 'Mozilla/4.0');
    UTL_HTTP.set_header(v_req, 'Host', v_host || ':' || v_port);
    UTL_HTTP.set_header(v_req, 'Connection', 'close');
    UTL_HTTP.set_header(v_req, 'Content-Type', 'text/xml;charset=UTF-8');
    UTL_HTTP.set_header(v_req, 'SOAPAction', '"DeleteVodafoneGroup_v1"');
    UTL_HTTP.set_header(v_req, 'Content-Length', LENGTH(v_req_xml));
    UTL_HTTP.write_text(v_req,  v_req_xml);
 
    v_resp := UTL_HTTP.get_response(v_req);
    
    DBMS_OUTPUT.put_line('Response> status_code: "' || v_resp.status_code || '"');
    DBMS_OUTPUT.put_line('Response> reason_phrase: "' ||v_resp.reason_phrase || '"');
    DBMS_OUTPUT.put_line('Response> http_version: "' ||v_resp.http_version || '"');
    
    BEGIN
    
        LOOP
            --UTL_HTTP.read_raw(v_resp, v_raw_data, v_buffer_size);
           -- v_line := UTL_RAW.cast_to_varchar2(v_raw_data);
          --  dbms_output.put_line(v_line);
            UTL_HTTP.read_line(v_resp,v_line);
            v_resp_clob := v_resp_clob || v_line;
        END LOOP;
       
        EXCEPTION
            WHEN UTL_HTTP.end_of_body THEN
                UTL_HTTP.end_response(v_resp);
    END;
 
    IF v_req.private_hndl IS NOT NULL THEN
        UTL_HTTP.end_request(v_req);
    END IF;
 
    IF v_resp.private_hndl IS NOT NULL THEN
        UTL_HTTP.end_response(v_resp);
    END IF;
    
  -- dbms_output.put_line(v_resp_clob);
    v_resp_xml := XMLTYPE(v_resp_clob);
  /* v_resp_xml := XMLTYPE('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
   <soapenv:Body>
      <soapenv:Fault>
         <faultcode>Server</faultcode>
         <faultstring>org.apache.xmlbeans.XmlException: error: The end-tag for element type  must end with a  delimiter.</faultstring>
      </soapenv:Fault>
   </soapenv:Body>
</soapenv:Envelope>');*/
    check_fault(v_resp_xml,v_namespace);
    v_resp_xml := v_resp_xml.extract('/soapenv:Envelope/soapenv:Body/sieb:DeleteVodafoneGroup_v1Response/Header/child::node()',v_namespace);
    
    dbms_output.put_line(v_resp_xml.getStringVal());
    
    v_result.responseCode := v_resp_xml.extract('/res:ResponseCode/child::node()',v_namespace).getStringVal();
    v_result.responseMsg  := v_resp_xml.extract('/res:ResponseMsg/child::node()',v_namespace).getStringVal();
    v_result.errorCode := v_resp_xml.extract('/res:ErrorCode/child::node()',v_namespace).getStringVal();
    v_result.errorDescription := v_resp_xml.extract('/res:ErrorDescription/child::node()',v_namespace).getStringVal();
    v_result.requestId := v_resp_xml.extract('/res:RequestId/child::node()',v_namespace).getStringVal();
    v_result.domain := v_resp_xml.extract('/res:Domain/child::node()',v_namespace).getStringVal();
    v_result.operation := v_resp_xml.extract('/res:Operation/child::node()',v_namespace).getStringVal();
    v_result.version := v_resp_xml.extract('/res:Version/child::node()',v_namespace).getStringVal();
    v_result.Attributes := v_resp_xml.extract('/res:Attributes/child::node()',v_namespace).getStringVal();
        
        
    dbms_output.put_line(v_result.Attributes);
    
   
EXCEPTION 
WHEN OTHERS THEN
v_err := SQLERRM;
  dbms_output.put_line('Err:'||v_err);
END;
 

