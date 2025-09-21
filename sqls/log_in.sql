
COLUMN myprompt NEW_VALUE prompt

SELECT
  SYS_CONTEXT('USERENV', 'DB_NAME')         AS myprompt
FROM dual;


SET SQLPROMPT '&prompt> '
