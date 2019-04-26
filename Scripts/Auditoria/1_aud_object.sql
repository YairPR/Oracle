--Relational Schema
--First we must create a relational schema to work on.

CREATE TABLE audit_logs (
  id              NUMBER(10)    NOT NULL,
  log_timestamp   TIMESTAMP     NOT NULL,
  username        VARCHAR2(30) ,NOT NULL,
  object_name     VARCHAR2(30)  NOT NULL,
  action          VARCHAR2(10)  NOT NULL,
  data            CLOB
)
/


CREATE PUBLIC SYNONYM audit_logs FOR SYS.audit_logs

ALTER TABLE audit_logs ADD (
  CONSTRAINT audit_logs_pk PRIMARY KEY (id)
)
/

CREATE SEQUENCE audit_logs_seq;

--Package
--Next we create the package that actually performs the inserts into the audit_logs table. This has
-- been separated out into a package so that addition control features, like on/off audit switches, can be added centrally.

CREATE OR REPLACE PACKAGE tsh_audit AS

PROCEDURE insert_log (p_username  IN  VARCHAR2,
                      p_object    IN  VARCHAR2,
                      p_action    IN  VARCHAR2,
                      p_data      IN  CLOB);
               
END;
/

CREATE OR REPLACE PACKAGE BODY tsh_audit AS

PROCEDURE insert_log (p_username  IN  VARCHAR2,
                      p_object    IN  VARCHAR2,
                      p_action    IN  VARCHAR2,
                      p_data      IN  CLOB) IS
BEGIN
  INSERT INTO audit_logs (
    id,
    log_timestamp,
    username,
    object_name,
    action,
    data)
  VALUES (
    audit_logs_seq.NEXTVAL,
    SYSTIMESTAMP,
    p_username,
    p_object,
    p_action,
    p_data
  );
END;
               
END;
/
