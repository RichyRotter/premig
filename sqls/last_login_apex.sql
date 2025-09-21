SELECT '$db_dbnm '||view_timestamp||' '||apex_user AS last_login
FROM
    apex_workspace_activity_log
WHERE
    apex_user IS NOT NULL
ORDER BY
    view_timestamp DESC
fetch first row only
/

