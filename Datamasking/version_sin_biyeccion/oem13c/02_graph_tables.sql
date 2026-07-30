Rem
Rem $Header: emdb/source/oracle/sysman/emdrep/sql/db/latest/subset/dsg_tables.sql /main/11 2017/02/08 02:47:45 gmeikand Exp $
Rem
Rem dsg_tables.sql
Rem
Rem Copyright (c) 2010, 2017, Oracle and/or its affiliates. 
Rem All rights reserved.
Rem
Rem    NAME
Rem      dsg_tables.sql - <one-line expansion of the name>
Rem
Rem    DESCRIPTION
Rem      <short description of component this file declares/defines>
Rem
Rem    NOTES
Rem      <other useful comments, qualifications, etc.>
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    ddsingha    06/16/16 - Project 60908: Provides support for long
Rem                           identifiers in DMS repository tables
Rem    amikhare    07/10/15 - The tables are renamed for EBRification of EM
Rem                           Repository in 13.1. The original table name is
Rem                           taken by an Editioning view. All your business
Rem                           logic would access the table via Editioning view.
Rem    jkati       10/28/14 - er-16665272 : support subset based on partition
Rem    mappusam    05/26/14 - bug-18816149 fix
Rem    mappusam    01/28/14 - bug-17988784 Fix (increase the table_name column
Rem                           size)
Rem    prakgupt    08/05/13 - Add additional columns for
Rem                           DB_DSG_PROCESSING_CHAIN_E
Rem    shmahaja    06/17/13 - adding support for enabling and disabling edges
Rem                           in subset processing
Rem    shmahaja    11/30/11 - removing key_type from primary key of
Rem                           DB_DSG_KEY_COLS_E
Rem    shmahaja    10/18/11 - moving all the ddls to this file and version
Rem                           specific things to the respective version folders
Rem    bkuchibh    03/23/10 - re-shuffled the content to 11.2.0.1 
Rem    bkuchibh    03/18/10 - Created
Rem

/***************************************************************************
drop SEQUENCE DB_DSG_TBLID_SEQ;
drop SEQUENCE DB_DSG_EDGEID_SEQ;

drop TABLE DB_DSG_ROW_IDS;
drop TABLE DB_DSG_IMPTS_E;
drop TABLE DB_DSG_KEY_COLS_E;
drop TABLE DB_DSG_EDGES_E;
drop TABLE DB_DSG_NODE_E;
drop TABLE DB_DSG_APPS_E;
***************************************************************************/

Rem
Rem TABLE DB_DSG_APPS_E
Rem
Rem PURPOSE
Rem     A Data Subset Graph (DSM) is based on an Subset Model, which in turn
Rem     to DDRM.
Rem     This table contains details on each 'application' present in the DDRM.
Rem     Each row represents an application.
Rem
Rem KEYS
Rem     Primary Key         - (DSM_ID, TGT_ID, APPL_SHORT_NAME)
Rem
Rem COLUMNS
Rem     DSM_ID              - Data Subset Model ID
Rem     TGT_ID              - Target GUID of the reference database
Rem     APPL_NAME           - Application name
Rem     APPL_SHORT_NAME     - Application short name
Rem     SCHEMA_NAME         - Application schema name
Rem     IS_APP_SCH_OTO      - An application can have one ore more schemas.
Rem                         - Does this application have only one schema i.e,
Rem                         - one-to-one mapping? Y/N
Rem     IS_SELECTED         - Is the app selected to be part of the subset? Y/N
Rem     IS_INCLUDE_ALL      - Include all the app tables in the subset? Y/N
Rem     IS_IA_PROCESSED     - Is Include All rule processed on this application
Rem     ACTUAL_DATA         - Actual size of the application data
Rem     DERIVED_DATA        - Actual size of derived data (indexes etc)
Rem     EXP_ACTUAL_DATA     - Expected size of the application after subset
Rem     EXP_DERIVED_DATA    - Actual size of derived data (indexes etc)
Rem     RULE_ID             - User defined rule ID
Rem

CREATE TABLE DB_DSG_APPS_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  APPL_NAME           VARCHAR2(512) NOT NULL,
  APPL_SHORT_NAME     VARCHAR2(512) NOT NULL,
  SCHEMA_NAME         VARCHAR2(512) NOT NULL,
  IS_APP_SCH_OTO      VARCHAR2(1),
  IS_SELECTED         VARCHAR2(1),
  IS_INCLUDE_ALL      VARCHAR2(1),
  IS_IA_PROCESSED     VARCHAR2(1),
  ACTUAL_DATA         NUMBER,
  DERIVED_DATA        NUMBER,
  EXP_ACTUAL_DATA     NUMBER,
  EXP_DERIVED_DATA    NUMBER,
  RULE_ID             INTEGER,
  CONSTRAINT DB_DSG_APPS_PK  PRIMARY KEY (DSM_ID, TGT_ID, APPL_SHORT_NAME) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_NODE_E
Rem
Rem PURPOSE
Rem     This table contains details on each table present in an application.
Rem     Each row represents a table.
Rem
Rem KEYS
Rem     Primary Key         - (DSM_ID, TGT_ID, APPL_SHORT_NAME, TABLE_NAME)
Rem     Unique key          - TABLE_ID generated using DB_DSG_TBLID_SEQ
Rem
Rem COLUMNS
Rem     DSM_ID              - Data Subset Model ID
Rem     TGT_ID              - Target GUID of the reference database
Rem     APPL_SHORT_NAME     - Application short name
Rem     SCHEMA_NAME         - Application schema name
Rem     RUNTIME_SCHEMA_NAME - Runtime Application schema name. This will be updated
Rem                         - based on the target selected for subset execution
Rem     TABLE_NAME          - Table name
Rem     TABLE_ID            - Unique id of this table
Rem     TABLE_TYPE          - Table type
Rem     PKEY_CNAME          - Primary key constraint name
Rem     PK_ROW_TBL          - Table name populated with primary key columns of
Rem                         - this table.
Rem     ROW_ID_TBL          - Table name populated with ROWIDs of this table
Rem     IS_IOT_TABLE        - Is this an IOT? Y/N
Rem     SRC_NUM_ROWS        - Number of rows in this table
Rem     EXPT_NUM_ROWS       - Expected number of rows in this table after subset
Rem     ACT_NUM_ROWS        - Actual number of rows in this table after subset
Rem     MAX_NUM_ROWS        - Max number of rows allowed in subset
Rem                         - % space constraint gets translated
Rem     AVG_ROW_SIZE        - Average row size of this table
Rem     IS_INCLUDE_ALL      - Include all rows in the subset? Y/N
Rem     IS_UD_RULE          - Is there a user-defined rule for this table? Y/N
Rem     IS_ACTIVE           - Is this node active? Y/N
Rem     IS_RULE_PROCESSED   - Is the rule on this node processed? Y/N
Rem     PULL_PARENTS        - Include parent tables in the subset? Y/N
Rem     PULL_CHILDREN       - Include child tables in the subset? Y/N
Rem     USE_SHADOW_TBL      - Use shadow tables? Y/N
Rem     UD_CLAUSE           - User defined 'where' clause
Rem     RUNTIME_UD_CLAUSE   - The runtime User defined 'where' clause. This will updated
Rem                         - based on the target selected for subset execution
Rem     RULE_ID             - Unique identifier of the user-defined rule
Rem     ROW_PERCENT         - % of rows to be included, 
Rem			    - for 'where clause' rules and 'all rows' rules
Rem

CREATE SEQUENCE DB_DSG_TBLID_SEQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOMAXVALUE
  NOCYCLE
  CACHE 20
  NOORDER;

CREATE TABLE DB_DSG_NODE_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  APPL_SHORT_NAME     VARCHAR2(512) NOT NULL,
  SCHEMA_NAME         VARCHAR2(512) NOT NULL,
  RUNTIME_SCHEMA_NAME VARCHAR2(512),
  TABLE_NAME          VARCHAR2(512) NOT NULL,
  TABLE_ID            INTEGER NOT NULL,
  TABLE_TYPE          VARCHAR2(30),
  PKEY_CNAME          VARCHAR2(512),
  PK_ROW_TBL          VARCHAR2(30),
  ROW_ID_TBL          VARCHAR2(30),
  IS_IOT_TABLE        VARCHAR2(1),
  SRC_NUM_ROWS        NUMBER,
  EXPT_NUM_ROWS       NUMBER,
  ACT_NUM_ROWS        NUMBER,
  MAX_NUM_ROWS        NUMBER,
  AVG_ROW_SIZE        NUMBER,
  IS_INCLUDE_ALL      VARCHAR2(1),
  IS_UD_RULE          VARCHAR2(1),
  IS_ACTIVE           VARCHAR2(1),
  IS_RULE_PROCESSED   VARCHAR2(1),
  PULL_PARENTS        VARCHAR2(1),
  PULL_CHILDREN       VARCHAR2(1),
  USE_SHADOW_TBL      VARCHAR2(1),
  UD_CLAUSE           VARCHAR2(4000),
  RUNTIME_UD_CLAUSE   VARCHAR2(4000),
  RULE_ID             INTEGER,
  ROW_PERCENT         NUMBER,
  COL_RULE_SIZE       NUMBER DEFAULT 0,
  PCLAUSE             CLOB,
  SPCLAUSE            CLOB,
  CONSTRAINT DB_DSG_NODE_PK  PRIMARY KEY (DSM_ID, TGT_ID, APPL_SHORT_NAME, TABLE_NAME) 
                               USING INDEX,
  CONSTRAINT DB_DSG_NODE_UC1 UNIQUE (TABLE_ID) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_EDGES_E
Rem
Rem PURPOSE
Rem     Captures the referential relationships between tables participating
Rem     in the Subset. Each row represents a relationship.
Rem
Rem KEYS
Rem     Primary Key         - (EDGE_ID)
Rem                         - we could matained pk on a bigger pair
Rem                         - but donot see the need, as this table is internal
Rem                         - and always go through the validation logic before
Rem                         - any insertion happens
Rem COLUMNS
Rem     DSM_ID              - Data Subset Model ID
Rem     TGT_ID              - Target GUID of the reference database
Rem     EDGE_ID             - Unique ID for this relationship
Rem     REF_SCH_NAME        - Schema name of the child/referencing table
Rem     REF_AS_NAME         - Application short name of the child table
Rem     REF_TABLE_NAME      - Child table name
Rem     REF_KEY_ID          - Unique key id of the child table columns
Rem     REF_KEY_HASH        - Hash value of the child table columns
Rem     PRI_SCH_NAME        - Schema name of the parent table
Rem     PRI_AS_NAME         - Application short name of the parent table
Rem     PRI_TABLE_NAME      - Parent table name
Rem     PRI_KEY_ID          - Unique key id of the parent table columns
Rem     PRI_KEY_HASH        - Hash value of the parent table columns
Rem     EDGE_AWF            - Edge Absolute weight factor
Rem                         - The ratio of parent rows to dependent rows
Rem     IS_EDGE_P_EST_PROCESSED - Is parent table estimation complete? Y/N
Rem     IS_EDGE_C_EST_PROCESSED - Is child table estimation complete? Y/N
Rem

CREATE SEQUENCE DB_DSG_EDGEID_SEQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOMAXVALUE
  NOCYCLE
  CACHE 20
  NOORDER;

CREATE TABLE DB_DSG_EDGES_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  EDGE_ID             INTEGER NOT NULL,
  REF_SCH_NAME        VARCHAR2(512),
  REF_AS_NAME         VARCHAR2(512),
  REF_TABLE_NAME      VARCHAR2(512),
  REF_KEY_ID          INTEGER,
  REF_KEY_HASH        VARCHAR2(40),
  PRI_SCH_NAME        VARCHAR2(512),
  PRI_AS_NAME         VARCHAR2(512),
  PRI_TABLE_NAME      VARCHAR2(512),
  PRI_KEY_ID          NUMBER,
  PRI_KEY_HASH        VARCHAR2(40),
  EDGE_AWF            NUMBER(38,2),
  IS_EDGE_P_EST_PROCESSED VARCHAR2(1),
  IS_EDGE_C_EST_PROCESSED VARCHAR2(1),
  CONSTRAINT DB_DSG_EDGES_PK  PRIMARY KEY (DSM_ID, TGT_ID, REF_KEY_ID, PRI_KEY_ID) 
                                USING INDEX,
  CONSTRAINT DB_DSG_EDGES_UK  UNIQUE (EDGE_ID) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_KEY_COLS_E
Rem
Rem PURPOSE
Rem     This table contains information about column groups (keys).
Rem     A 'column group' is a generic concept and can be used to store
Rem     1. Primary key column group
Rem     2. Ref key column group
Rem     Each row in this table represents a column.
Rem
Rem KEYS
Rem     Primary Key - (DSM_ID, TGT_ID, KEY_ID, AS_NAME, TABLE_NAME, COLUMN_NAME)
Rem
Rem COLUMNS
Rem     DSM_ID      - Data Subset Model ID
Rem     TGT_ID      - Target GUID of the reference database
Rem     KEY_ID      - Unique id of the column group
Rem     KEY_TYPE    - Key type: 1=parent key, 2=dependent key
Rem     SCH_NAME    - Schema name of the table having this column
Rem     AS_NAME     - Application short name
Rem     TABLE_NAME  - Table name
Rem     COLUMN_NAME - Column name
Rem     POSITION    - Column position in the
Rem

CREATE SEQUENCE DB_DSG_KEY_ID_SEQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOMAXVALUE
  NOCYCLE
  CACHE 20
  NOORDER;

CREATE TABLE DB_DSG_KEY_COLS_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  KEY_ID              INTEGER NOT NULL,
  KEY_TYPE            NUMBER (2,0),
  SCH_NAME            VARCHAR2(512),
  AS_NAME             VARCHAR2(512),
  TABLE_NAME          VARCHAR2(512),
  COLUMN_NAME         VARCHAR2(512),
  POSITION            NUMBER (2,0),
  CONSTRAINT DB_DSG_KEY_COLS_PK  PRIMARY KEY (DSM_ID, TGT_ID, KEY_ID, COLUMN_NAME) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_IMPTS_E
Rem
Rem PURPOSE
Rem     Captures the impact of a subset rule on each table/node.
Rem     Each row represents the impact of a table rule
Rem
Rem KEYS
Rem     Primary Key     - (DSM_ID, TGT_ID, RULE_ID, IMPT_TBL_ID)
Rem     Foreign Key     - IMPT_TBL_ID references DB_DSG_NODE_E.TABLE_ID which
Rem                     - is unique
Rem COLUMNS
Rem     DSM_ID          - Data Subset Model ID
Rem     TGT_ID          - Target GUID of the reference database
Rem     RULE_ID         - Unique rule ID
Rem     IMPT_TBL_ID     - Unique table ID
Rem     NUM_SA_ROWS     - Estimated number of rows affected by the rule (standalone)
Rem     NUM_AJ_ROWS     - Estimated number of rows affected by the rule (adjusted)
Rem     IS_PROCESSED    - Is processing of the node/table complete? Y/N
Rem     IS_PARENT       - Is table parent table of rule (its table)
Rem     IS_CHILD        - Is table child table of rule (its table) 
Rem
CREATE TABLE DB_DSG_IMPTS_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  RULE_ID             INTEGER NOT NULL,
  IMPT_TBL_ID         INTEGER NOT NULL,
  NUM_SA_ROWS         NUMBER,
  NUM_AJ_ROWS         NUMBER,
  IS_PROCESSED        VARCHAR2(1),
  IS_PARENT           VARCHAR2(1),
  IS_CHILD            VARCHAR2(1),
  CONSTRAINT DB_DSG_IMPTS_PK  PRIMARY KEY (DSM_ID, TGT_ID, RULE_ID, IMPT_TBL_ID) USING INDEX,
  CONSTRAINT DB_DSG_IMPTS_FK1
    FOREIGN KEY (IMPT_TBL_ID)
    REFERENCES DB_DSG_NODE_E(TABLE_ID)
) ;

Rem
Rem TABLE DB_DSG_DYNAMIC_SCRIPTS_E
Rem
Rem PURPOSE
Rem     This table stores the dynamic scripts (packages) required for subset
Rem     execution. This will contain CLOBS for each script. The column names
Rem     will be kept generic.
Rem
Rem KEYS
Rem     Primary Key     - (DSM_ID, TGT_ID).
Rem
Rem COLUMNS
Rem     DSM_ID          - Data Subset Model ID
Rem     TGT_ID          - Target GUID of the database selected for subset execution.
Rem     SCRIPT1         - subset_exec_param.lst stored as a CLOB
Rem     SCRIPT2         - for additional scripts
Rem     DUMP1           - graph data stored as a CLOB
Rem     DUMP2           - for additional dumps
Rem
Rem
CREATE TABLE DB_DSG_DYNAMIC_SCRIPTS_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  SCRIPT1             CLOB,
  SCRIPT2             CLOB,
  DUMP1               CLOB,
  DUMP2               CLOB,
  CONSTRAINT DB_DSG_DYNAMIC_SCRIPTS_PK  PRIMARY KEY (DSM_ID, TGT_ID) USING INDEX
) ;


Rem
Rem TABLE DB_DSG_SCHEMA_MAP_E
Rem
Rem PURPOSE
Rem     This table stores mapping between the design time and runtime schema
Rem
Rem KEYS
Rem     Primary Key     - (DSM_ID, TGT_ID).
Rem
Rem COLUMNS
Rem     DSM_ID              - Data Subset Model ID
Rem     TGT_ID              - Target GUID of the database selected for subset execution.
Rem     APPL_SHORT_NAME     - Application short name
Rem     SCHEMA_NAME         - Application schema name
Rem     RUNTIME_SCHEMA_NAME - Runtime Application schema name. This will be updated
Rem                         - based on the target selected for subset execution
Rem

CREATE TABLE DB_DSG_SCHEMA_MAP_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  APPL_SHORT_NAME     VARCHAR2(512) NOT NULL,
  RUNTIME_SCHEMA_NAME VARCHAR2(512),
  CONSTRAINT DB_DSG_SCHEMA_MAP_PK  PRIMARY KEY (DSM_ID, TGT_ID, APPL_SHORT_NAME) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_SPL_EDGES_E
Rem
Rem PURPOSE
Rem     This table will store all the edges for a rule excluded from subset processing
Rem
Rem KEYS
Rem     Primary Key     - (DSM_ID, TGT_ID, RULE_ID, EDGE_ID).
Rem
Rem COLUMNS
Rem     DSM_ID              - Data Subset Model ID.
Rem     TGT_ID              - Target GUID of the database selected for subset execution.
Rem     RULE_ID             - The rule for which extra edge processing is to be done.
Rem     EDGE_ID             - The edge to be included or disabled.
Rem     PROCESSING_TYPE     - 1 for excluding, 2 for include child
Rem

CREATE TABLE DB_DSG_SPL_EDGES_E
(
  DSM_ID              INTEGER NOT NULL,
  TGT_ID              RAW(16),
  RULE_ID             INTEGER,
  EDGE_ID             INTEGER,
  PROCESSING_TYPE     INTEGER,
  CONSTRAINT DB_DSG_EXCLUDED_EDGES_PK PRIMARY KEY (DSM_ID, TGT_ID, RULE_ID, EDGE_ID) USING INDEX
) ;

Rem
Rem TABLE DB_DSG_PROCESSING_CHAIN_E
Rem
Rem PURPOSE
Rem     This table will store the steps by which the subset processing was done
Rem     This table will be used to display the steps on the UI and will give the users
Rem     an option to remove ref relations from the processing chain
Rem
Rem KEYS
Rem     Primary Key     - (DSM_ID, RULE_ID, STEP_ID).
Rem     Foreign Key     - (DSM_ID, RULE_ID, PARENT_STEP_ID) -> SELF
Rem
Rem COLUMNS
Rem     DSM_ID                  - Data Subset Model ID.
Rem     RULE_ID                 - The rule ID.
Rem     EDGE_ID                 - ID of the ref relation.
Rem     AS_NAME                 - application short name
Rem     TABLE_NAME              - table name
Rem     SOURCE_NUM_ROWS         - Number of rows in table before subset
Rem     IMPACTED_ROWS           - The approximate number of rows that got included
Rem                               during this step
Rem     RELATION                - The relationship between the driving table and current table
Rem                               P for parent, C for child
Rem     STEP_ID                 - ID of the current step
Rem     PARENT_STEP_ID          - ID of the parent step, this will help is showing the hierarchy
Rem     ADDITIONAL_DESC_AVBL    - whether or not the table contains more children than already processed
Rem     DISABLED_EXP            - disabled explicitly, will be 'Y' when a user disables a ref relation.
Rem     DISABLED_IMP            - disabled implicitly, will be 'Y' when this nodes processing was disabled
Rem                               because of dependency
Rem     SELECTED                - to map directly to UI checkbox selection
Rem     PJOIN_COL               - Formatted values for Parent join column
Rem     CJOIN_COL               - Formatted values for Child join columns
Rem     AVG_ROW_LEN             - Average row length for the table
Rem

CREATE TABLE DB_DSG_PROCESSING_CHAIN_E
(
  DSM_ID                INTEGER NOT NULL,
  RULE_ID               INTEGER,
  EDGE_ID               INTEGER,
  AS_NAME               VARCHAR2(512),
  TABLE_NAME            VARCHAR2(512),
  SOURCE_NUM_ROWS       INTEGER,
  IMPACTED_ROWS         INTEGER,
  RELATION              VARCHAR2(1),
  STEP_ID               INTEGER,
  PARENT_STEP_ID        INTEGER,
  ADDITIONAL_DESC_AVBL  VARCHAR2(1) DEFAULT 'N',
  DISABLED_EXP          VARCHAR2(1) DEFAULT 'N',
  DISABLED_IMP          VARCHAR2(1) DEFAULT 'N',
  SELECTED              VARCHAR2(1) DEFAULT 'Y',
  PJOIN_COL             VARCHAR2(4000),
  CJOIN_COL             VARCHAR2(4000),
  AVG_ROW_LEN           NUMBER(38,2),
  CONSTRAINT DB_DSG_PROCESSING_CHAIN_PK PRIMARY KEY (DSM_ID, RULE_ID, STEP_ID) USING INDEX
) ;

