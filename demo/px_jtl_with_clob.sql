-- drop table px_jtl_with_clob purge;

create table px_jtl_with_clob (
    id            number        generated by default on null as identity (start with 1) primary key not null
  , name_jtl      varchar2(500)   not null constraint px_jtl_with_clob_name_tl_ck CHECK (name_jtl is json(strict))
  , description_jtl clob not null constraint px_jtl_with_clob_desc_tl_ck CHECK (description_jtl is json(strict))
  , alias         varchar2(32)
  , active_ind    varchar2(1)   not null
  , created_by    varchar2(60) default 
                    coalesce(
                        sys_context('APEX$SESSION','app_user')
                      , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                      , sys_context('userenv','session_user')
                    )
                    not null
  , created_on    date         default sysdate not null
  , updated_by    varchar2(60)
  , updated_on    date
  , constraint px_jtl_with_clob_ck_active
      check (active_ind in ('Y', 'N'))
)
enable primary key using index
/

comment on table px_jtl_with_clob is 'Demo table to test clobs';

comment on column px_jtl_with_clob.name_jtl is 'JSON data with the language as keys. Syntax: [{"l": "us", "tl": "Project Analysis"}]';
comment on column px_jtl_with_clob.description_jtl is 'JSON data with the language as keys. Syntax: [{"l": "us", "tl": "Project Analysis"}]';
comment on column px_jtl_with_clob.active_ind is 'Is the record enabled Y/N?';
comment on column px_jtl_with_clob.created_by is 'User that created this record';
comment on column px_jtl_with_clob.created_on is 'Date the record was first created';
comment on column px_jtl_with_clob.updated_by is 'User that last modified this record';
comment on column px_jtl_with_clob.updated_on is 'Date the record was last modified';


--------------------------------------------------------
--  DDL for Trigger px_jtl_with_clob_u
--------------------------------------------------------
create or replace trigger px_jtl_with_clob_u
before update
on px_jtl_with_clob
referencing old as old new as new
for each row
begin
  :new.updated_on := sysdate;
  :new.updated_by := coalesce(
                         sys_context('APEX$SESSION','app_user')
                       , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                       , sys_context('userenv','session_user')
                     );
end;
/
alter trigger px_jtl_with_clob_u enable;