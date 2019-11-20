CREATE OR REPLACE PACKAGE SSI_AVATIER_ID_ENFORCER
IS
  /*
  ||===========================================================================================================
  ||          Owner: Stage Stores Inc.
  ||    Application: Avatier ID Enforcer in RMS
  ||      File Name: ssi_avatier_id_enforcer_spec.sql
  ||           Date: 05/15/2018
  ||         Author: Veera Adepu
  ||    Description: This Package will provision and maintain RMS user accounts - executed from Avatier.
  ||      Called By: Avatier ID Enforcer
  ||     Modification History :
  ||     Who          Date            Reason
  ||		Rakesh Suravarapu	11/12/2019	Jenkins Build 1.1
  ||		Rakesh Suravarapu	11/19/2019	Jenkins Build 1.2
  ||		Rakesh Suravarapu	11/19/2019	Jenkins Build 1.3
  ||===========================================================================================================
  */
  FUNCTION F_Check_Account_Exists(
      p_UserId IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Create_Account(
      p_UserId   IN VARCHAR2,
      p_Password IN VARCHAR2,
      p_profile  IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Assign_Roles(
      p_UserId   IN VARCHAR2,
      p_rolename IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Delete_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Disable_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Unlock_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION F_Reset_Password(
      p_UserId       IN VARCHAR2,
      p_New_Password IN VARCHAR2)
    RETURN NUMBER;

END SSI_AVATIER_ID_ENFORCER;
/


CREATE OR REPLACE PACKAGE BODY         SSI_AVATIER_ID_ENFORCER
IS
  /*
  ||===========================================================================================================
  ||          Owner: Stage Stores Inc.
  ||    Application: Avatier ID Enforcer in RMS
  ||      File Name: ssi_avatier_id_enforcer_body.sql
  ||           Date: 04/29/2018
  ||         Author: Veera Adepu
  ||    Description: This Package will provision and maintain RMS user accounts - executed from Avatier.
  ||      Called By: Avatier ID Enforcer
  ||     Modification History :
  ||     Who          Date            Reason
  ||		Rakesh Suravarapu	11/12/2019	Jenkins Build 1.1
  ||===========================================================================================================
  */
  e_service_Account  EXCEPTION;
  e_notexist_Account EXCEPTION;
  e_Existing_Account EXCEPTION;
  CURSOR C_Chk_Account(cp_UserId IN VARCHAR2)
  IS
    SELECT NVL(
      (SELECT code_desc
      FROM ssi_avatier_code_detail
      WHERE code_type = 'RMSP'
      AND code_desc   = du.profile
      ), 'SERVICE ACCOUNT') profile
    FROM DBA_USERS du
    WHERE username = cp_UserId;
    /*
    F_Check_Account_Exists function checks account exists or not
    return code 0 : account doesn't exists
    return code 1 : account  exists
    */
    FUNCTION F_Check_Account_Exists(
        p_UserId IN VARCHAR2)
      RETURN NUMBER
    IS
      v_exists NUMBER := 0;
      v_profile DBA_USERS.PROFILE%TYPE;
      v_Return_Code NUMBER;
      v_Error_Msg   VARCHAR2(1000);
	  v_userid DBA_USERS.username%TYPE := upper(p_UserId);
    BEGIN
	
      OPEN C_Chk_Account(v_userid);
      FETCH C_Chk_Account INTO v_profile;
      CLOSE C_Chk_Account;
      IF v_profile    IS NOT NULL THEN
        v_Error_Msg   := 'Account already exists with Profile ' || v_profile;
        v_Return_Code := 1;
        RAISE e_Existing_Account;
      ELSE
        v_Return_Code := 0; -- Account doesn't exsit.
      END IF;
      RETURN(v_Return_Code);
    EXCEPTION
    WHEN e_Existing_Account THEN
      --RAISE_APPLICATION_ERROR(-20001, v_Error_Msg);
      RETURN(v_Return_Code);
    WHEN OTHERS THEN
      v_Return_Code := 1;
      v_Error_Msg   := 'ERROR executing F_Check_Account_Exists :: ' || SQLCODE || ' - ' || SQLERRM;
      Raise_Application_Error(-20000, v_Error_Msg);
      RETURN(v_Return_Code);
    END F_Check_Account_Exists;
  /*
  || This function creates database user account in RMS
  || v_Return_Code = 0 -- Success Status; 1 -- Failure
  */
  FUNCTION F_Create_Account(
      p_UserId   IN VARCHAR2,
      p_Password IN VARCHAR2,
      p_profile  IN VARCHAR2)
    RETURN NUMBER
  IS
    v_user_profile        VARCHAR2(50) := upper(p_profile);
    v_Return_Code         NUMBER;
    v_account_exists_code NUMBER;
    v_Error_Msg           VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
	e_notexist_profile  exception ;
	v_exists               number ;
	v_user_ts              varchar2(100);
	v_temp_ts              varchar2(100);
  BEGIN
    -- Check if the user account exists in the system
    v_account_exists_code   := F_Check_Account_Exists(v_userid);
dbms_output.put_line('v_account_exists_code - '||v_account_exists_code);
    IF v_account_exists_code = 0
      --doesn't exists
      THEN
	  --check profile valid are not
	  begin
	  select 1 into v_exists from dba_users
	  where profile = v_user_profile
	  and rownum < 2 ;
dbms_output.put_line('v_exists - '||v_exists);
	  
	  exception when no_data_found then
	  v_Return_Code := 1;
dbms_output.put_line('1 v_Return_Code - '||v_Return_Code);
	  v_Error_Msg   := 'Profile not found';
	  --raise e_notexist_profile;
	  end;
	  
	  select code into v_user_ts from ssi_avatier_code_detail
	  where code_type = 'DFTS' ;
	  
	  select code into v_temp_ts from ssi_avatier_code_detail
	  where code_type = 'TMTS' ;
	  
      EXECUTE IMMEDIATE 'CREATE USER ' || v_userid || ' IDENTIFIED BY ' || p_Password || '  DEFAULT TABLESPACE '|| v_user_ts ||' TEMPORARY TABLESPACE ' || v_temp_ts  ||            
                       ' QUOTA UNLIMITED ON users  QUOTA UNLIMITED ON temp              
                        PROFILE ' || v_user_profile;
      v_Return_Code := 0; -- Success Status
dbms_output.put_line('2 v_Return_Code - '||v_Return_Code);
    ELSE
      v_Error_Msg   := 'Account already exists';
      v_Return_Code := 1;
dbms_output.put_line('3 v_Return_Code - '||v_Return_Code);
      --RAISE e_Existing_Account;
    END IF;
    RETURN(v_Return_Code);
  EXCEPTION
  WHEN e_Existing_Account THEN
    --RAISE_APPLICATION_ERROR(-20001, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notexist_profile THEN
    --RAISE_APPLICATION_ERROR(-20004, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing f_Create_Account :: ' || SQLERRM;
    --Raise_Application_Error(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END F_Create_Account;
/*
|| This function will update the RMS User account and grant necessary RMS roles.
|| The following database roles will be granted:
||  Connect
||  READ_ONLY  (DEFAULT)
||  CREATE SESSION  (DEFAULT)
|| rms_secured_full_access
|| v_Return_Code = 0 -- Success Status; 1 -- Failure
*/
  FUNCTION F_Assign_Roles(
      p_UserId   IN VARCHAR2,
      p_rolename IN VARCHAR2)
    RETURN NUMBER
  IS
    v_profile DBA_USERS.PROFILE%TYPE;
    v_user_privilege NUMBER(1) := 0;
    v_Return_Code    NUMBER;
    v_Error_Msg      VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
  BEGIN
    OPEN C_Chk_Account(v_userid);
    FETCH C_Chk_Account INTO v_profile;
    CLOSE C_Chk_Account;
dbms_output.put_line('v_profile - '||v_profile);
    IF v_profile    IS NOT NULL THEN
      IF (v_profile <> 'SERVICE ACCOUNT') -- User Account  exists
        THEN
        -- Grant necessary database roles
        --EXECUTE IMMEDIATE 'GRANT connect TO ' || v_userid;
        EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO ' || v_userid;
        EXECUTE IMMEDIATE 'GRANT READ_ONLY TO ' || v_userid;
        EXECUTE IMMEDIATE 'GRANT RMS_SECURED_FULL_ACCESS TO ' || v_userid;
		EXECUTE IMMEDIATE 'GRANT ' || p_rolename || ' TO ' || v_userid;
        EXECUTE IMMEDIATE 'ALTER USER ' || v_userid || ' DEFAULT ROLE ALL EXCEPT READ_ONLY';
        v_Return_Code := 0; -- Success Status
      ELSE
        v_Return_Code := 1;
        v_Error_Msg   := 'ERROR :: Cannot assign roles to ' || v_userid || ' With Service Account';
        raise e_service_Account;
      END IF;
    ELSE
      v_Return_Code := 1;
      v_Error_Msg   := 'Account does not exist in RMS';
      raise e_notExist_Account;
    END IF;
    RETURN(v_Return_Code);
  EXCEPTION
   WHEN e_service_Account THEN
    --RAISE_APPLICATION_ERROR(-20003, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notExist_Account THEN
    --RAISE_APPLICATION_ERROR(-20001, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing v_Assign_Roles :: ' || SQLERRM;
    --Raise_Application_Error(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END F_Assign_Roles;
/*
|| This function drops database user account in RMS
|| It checks that the account being dropped is NOT a service account
|| v_Return_Code = 0 -- Success Status; 1 -- Failure
*/
  FUNCTION F_Delete_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER
  IS
    v_profile DBA_USERS.PROFILE%TYPE;
    v_delete      BOOLEAN := FALSE;
    v_Return_Code NUMBER;
    v_Error_Msg   VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
  BEGIN
    -- Check that the user being dropped is NOT a service account. It should only be an RDM user ('RDM_RF','RDM_WEB','SSI_DEVELOPER')
    OPEN C_Chk_Account(v_userid);
    FETCH C_Chk_Account
    INTO v_profile;
    CLOSE C_Chk_Account;
    IF v_profile   IS NOT NULL THEN
      IF v_profile <> 'SERVICE ACCOUNT' THEN
        v_delete   := TRUE;
      ELSE
        v_delete      := FALSE;
        v_Return_Code := 1;
        v_Error_Msg   := 'ERROR :: Cannot delete ' || v_userid || ' With Service Account';
        raise e_service_Account;
      END IF;
    ELSE
      v_delete      := FALSE;
      v_Return_Code := 1;
      v_Error_Msg   := 'ERROR :: Invalid account for deletion ' || v_userid;
      raise e_notexist_Account;
    END IF;
    IF v_delete THEN
      -- Revoke granted roles
      FOR granted_roles IN
      (SELECT granted_role FROM sys.dba_role_privs WHERE grantee = v_userid
      )
      LOOP
        BEGIN
          EXECUTE IMMEDIATE 'REVOKE ' || granted_roles.granted_role || ' FROM ' || v_userid;
        EXCEPTION
        WHEN OTHERS THEN
          v_Return_Code := 1;
          v_Error_Msg   := 'ERROR Revoking Roles from User ' || v_userid || ' :: ' || SQLERRM;
          raise;
        END;
      END LOOP;
      EXECUTE IMMEDIATE 'DROP USER ' || v_userid || ' CASCADE';
      v_Return_Code := 0;
    END IF;
    RETURN(v_Return_Code);
  EXCEPTION
  WHEN e_service_Account THEN
    --RAISE_APPLICATION_ERROR(-20003, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notexist_Account THEN
    --RAISE_APPLICATION_ERROR(-20002, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    ROLLBACK;
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing v_Delete_Account :: ' || SQLERRM;
    RAISE_APPLICATION_ERROR(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END F_Delete_Account;
/*
|| This function Disable database user account in RDM
||v_Return_Code = 0 -- Success Status; 1 -- Failure
*/
  FUNCTION F_Disable_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER
  IS
    v_profile DBA_USERS.PROFILE%TYPE;
    v_disable     BOOLEAN := FALSE;
    v_Return_Code NUMBER;
    v_Error_Msg   VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
  BEGIN
    -- Check that the user being locked is NOT a service account. It should only be an RDM user ('RDM_RF','RDM_WEB','SSI_DEVELOPER')
    OPEN C_Chk_Account(v_userid);
    FETCH C_Chk_Account INTO v_profile;
    CLOSE C_Chk_Account;
    IF v_profile   IS NOT NULL THEN
      IF v_profile <> 'SERVICE ACCOUNT' THEN
        v_disable  := TRUE;
      ELSE
        v_disable     := FALSE;
        v_Return_Code := 1;
        v_Error_Msg   := 'ERROR :: Cannot disable ' || v_userid || ' With Service Account';
        raise e_service_Account;
      END IF;
    ELSE
      v_disable     := FALSE;
      v_Return_Code := 1;
      v_Error_Msg   := 'ERROR :: Account does not exist ' || v_userid;
      raise e_notexist_Account;
    END IF;
    IF v_disable THEN
      EXECUTE IMMEDIATE 'ALTER USER ' || v_userid || ' ACCOUNT LOCK';
    END IF;
    v_Return_Code := 0;
	RETURN(v_Return_Code);
  EXCEPTION
  WHEN e_service_Account THEN
    RAISE_APPLICATION_ERROR(-20003, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notexist_Account THEN
    RAISE_APPLICATION_ERROR(-20002, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    ROLLBACK;
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing F_Disable_Account :: ' || SQLERRM;
    RAISE_APPLICATION_ERROR(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END F_Disable_Account;
/*
|| This function unlocks database user account in RDM
|| v_Return_Code = 0 -- Success Status; 1 -- Failure
*/
  FUNCTION F_Unlock_Account(
      p_UserId IN VARCHAR2)
    RETURN NUMBER
  IS
    v_Unlock BOOLEAN := FALSE;
    v_profile DBA_USERS.PROFILE%TYPE;
    v_Return_Code NUMBER;
    v_Error_Msg   VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
  BEGIN
    -- Check that the user being unlocked is NOT a service account. It should only be an RDM user ('RDM_RF','RDM_WEB','SSI_DEVELOPER')
    OPEN C_Chk_Account(v_userid);
    FETCH C_Chk_Account INTO v_profile;
    CLOSE C_Chk_Account;
    IF v_profile   IS NOT NULL THEN
      IF v_profile <> 'SERVICE ACCOUNT' THEN
        v_Unlock   := TRUE;
      ELSE
        v_Unlock      := FALSE;
        v_Return_Code := 1;
        v_Error_Msg   := 'ERROR :: Cannot Unlock ' || v_userid || ' With Service Account';
        raise e_service_Account;
      END IF;
    ELSE
      v_Unlock      := FALSE;
      v_Return_Code := 1;
      v_Error_Msg   := 'ERROR :: Invalid account for Unlocking ' || v_userid;
      raise e_notexist_Account;
    END IF;
    IF v_Unlock THEN
      EXECUTE IMMEDIATE 'ALTER USER ' || v_userid || ' ACCOUNT UNLOCK';
    END IF;
    v_Return_Code := 0;
    RETURN(v_Return_Code);
  EXCEPTION
  WHEN e_service_Account THEN
    RAISE_APPLICATION_ERROR(-20003, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notexist_Account THEN
    RAISE_APPLICATION_ERROR(-20002, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    ROLLBACK;
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing F_Disable_Account :: ' || SQLERRM;
    RAISE_APPLICATION_ERROR(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END f_Unlock_Account;
/*
|| This function resets password for database user account in RDM
|| v_Return_Code = 0 -- Success Status; 1 -- Failure
*/
  FUNCTION f_Reset_Password(
      p_UserId       IN VARCHAR2,
      p_New_Password IN VARCHAR2)
    RETURN NUMBER
  IS
    v_Reset BOOLEAN := FALSE;
    v_profile DBA_USERS.PROFILE%TYPE;
    v_Return_Code NUMBER;
    v_Error_Msg   VARCHAR2(1000);
	v_userid DBA_USERS.username%TYPE := upper(p_UserId);
  BEGIN
    -- Check that the user being reset is NOT a service account. It should only be an RDM user ('RDM_RF','RDM_WEB','SSI_DEVELOPER')
    OPEN C_Chk_Account(v_userid);
    FETCH C_Chk_Account INTO v_profile;
    CLOSE C_Chk_Account;
    IF v_profile   IS NOT NULL THEN
      IF v_profile <> 'SERVICE ACCOUNT' THEN
        v_Reset    := TRUE;
      ELSE
        v_Reset       := FALSE;
        v_Return_Code := 1;
        v_Error_Msg   := 'ERROR :: Cannot Reset password for ' || v_userid || ' With Service Account';
        raise e_service_account;
      END IF;
    ELSE
      v_Reset       := FALSE;
      v_Return_Code := 1;
      v_Error_Msg   := 'ERROR :: Invalid account for Password Reset ' || v_userid;
      raise e_notexist_account;
    END IF;
    IF v_Reset THEN
      EXECUTE IMMEDIATE 'ALTER USER ' || v_userid || ' IDENTIFIED BY ' || p_New_Password;
    END IF;
    v_Return_Code := 0;
    RETURN(v_Return_Code);
  EXCEPTION
  WHEN e_service_Account THEN
    RAISE_APPLICATION_ERROR(-20003, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN e_notexist_Account THEN
    RAISE_APPLICATION_ERROR(-20002, v_Error_Msg);
    RETURN(v_Return_Code);
  WHEN OTHERS THEN
    ROLLBACK;
    v_Return_Code := 1;
    v_Error_Msg   := 'ERROR executing F_Disable_Account :: ' || SQLERRM;
    RAISE_APPLICATION_ERROR(-20000, v_Error_Msg);
    RETURN(v_Return_Code);
  END f_Reset_Password;
END SSI_AVATIER_ID_ENFORCER;
/
