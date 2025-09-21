create or replace PROCEDURE P_MAIL_SEND 
(
   v_From VARCHAR2,
   v_Recipient   VARCHAR2,
   v_Subject   VARCHAR2,
   v_body  VARCHAR2,
   v_port  NUMBER
)
 AUTHID CURRENT_USER IS
   objConnection UTL_SMTP.CONNECTION;
   vrData        VARCHAR2(32000);
-- ------------------------------------------------------------------------------------------
--
-- ------------------------------------------------------------------------------------------

  v_Mail_Host   VARCHAR2(30) := 'smtpout.basf.net';
  v_MType  VARCHAR2(30) := 'text/plain; charset=us-ascii';
  v_Mail_Conn utl_smtp.Connection;
  
  BEGIN
  
        v_Mail_Conn := utl_smtp.Open_Connection(v_Mail_Host, v_port);
        utl_smtp.Helo(v_Mail_Conn, v_Mail_Host);
        utl_smtp.Mail(v_Mail_Conn, v_From);
        utl_smtp.Rcpt(v_Mail_Conn, v_Recipient);
        utl_smtp.Data(v_Mail_Conn,
              'Date: '   || to_char(sysdate, 'Dy, DD Mon YYYY hh24:mi:ss') || UTL_TCP.CRLF ||
              'From: '   || v_From || UTL_TCP.CRLF ||
              'Subject: '|| v_Subject || UTL_TCP.CRLF ||
              'To: '     || v_Recipient || UTL_TCP.CRLF || v_Body || UTL_TCP.CRLF
            );
        utl_smtp.Quit(v_mail_conn);
        
      EXCEPTION
        WHEN utl_smtp.Transient_Error OR utl_smtp.Permanent_Error then
             raise_application_error(-20000, 'Unable to send mail', TRUE);
  END;
/
