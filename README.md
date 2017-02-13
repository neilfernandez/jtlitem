# APEX JTL Item Plugin

An Oracle APEX Item plugin for storing multi-language translations (MLS) in a JSON column.

This plugin allows you to store multiple language translations on a **single table column**. Optionally, the user can popup a dialog and edit all the available translations.

### Demo
[Run Demo](https://apex.oracle.com/pls/apex/f?p=97705)

### Preview
![Alt text](/preview.gif?raw=true "Preview")

### How to use?

Add a column with a `_JTL` suffix to your table (or any other suffix you like). For example, a `NAME` column would become `NAME_JTL`:

```
create table px_projects (
    id            number        generated by default on null as identity (start with 1) primary key not null
  , name_jtl      varchar2(500) not null constraint px_projects_tl_ck CHECK (name_jtl is json(strict))
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
  , constraint px_projects_ck_active
      check (active_ind in ('Y', 'N'))
)
enable primary key using index
/
```

Use a size that is `{Required Size} x {# of Languages} + offset`. The offset is around 18 per language.

When you create the APEX item, select a size for the item that matches your desired size per translated entry.

#### Plugin Component Attributes
* "Enabled Language List": The Enabled Language List must be a JavaScript array with the supported application languages. The sort order matters and the first language should be the Application's Primary Language. It is ~recommended~ required that when new languages are enabled for the applicating that the JSON columns be updated to include the new language.
* "Messages": Use this setting to specify what messages should be displayed to users in different parts of the plugin. For example, buttons and dialog.

#### Plugin Item Attributes
* "Session Language": use it to override the currently selected APEX language.  You should normally leave it empty.
* "Edit Languages": Controls whether the user will see the translation button "globe". It accepts a PL/SQL Function Returning Boolean.
**IMPORTANT** The "Edit Languages" field to `return true;` to see the globe button.

#### Other Settings
Optionally, use the `APEX.PAGE_ITEM_IS_REQUIRED` message to translate your "#LABEL# must have some value." to your correct language.  The plugin `validate` function will fetch this value (via `wwv_flow_lang.system_message`) when the "Required" attribute is set.

#### Accessing your Data

The stored JSON format structure for a translation column is of this form:

```
[ {"l": "us", "tl": "Project Analysis"}
, {"l": "fr", "tl": "Analyse de projet"}
, {"l": "es", "tl": "Analisis de projecto"}]
```

Where `l` is the language code, and `tl` is the translation.

In general, the only time you care about the stored format is when you need to seed data in your tables. Otherwise, the plugin handles the JSON structure for you.

Thanks to the new JSON funtionality on 12c we can extract our JSON data with a `JSON_TABLE` command. if you're on 11g [see here](#running-in-11g-without-json-columns).

```
create or replace view px_projects_vl
as
select t.id
     , t.name_jtl
     , jd.lang
     , jd.tls name
     , t.alias
     , t.active_ind
     , t.created_by
     , t.created_on
     , t.updated_by
     , t.updated_on
  from px_projects t
     , json_table(t.name_jtl, '$[*]'
        columns (
             lang varchar2(10)      path '$.l'
           , tl   varchar2(60 char) path '$.tl'
       )) jd
 where jd.lang = (select nvl(apex_util.get_session_lang,'en') from dual)
/
```

#### Programmatic access to your data

The provided package `tk_jtl_plugin` contains several useful [functions and procedures](docs/tk_jtl_plugin.md).

For example, use `tk_jtl_plugin.get_tl_value` on a validation to verify a name is unique within a language.

```
select 1
from px_projects_vl
where id <> nvl(:P25_ID, -1)
  and name = tk_jtl_plugin.get_tl_value(:P25_NAME_JTL)
```

Also, the plugin `render` and `validate` functions are part of the `tk_jtl_plugin` package. You'll want to remove the code from the Plugin Source and change the render and validate functions to `tk_jtl_plugin.render` and `tk_jtl_plugin.validate` respectively.


### Disclaimer
This plugin is still work in progress. Use at your own risk and without any warranties.


### Running in 11g without JSON columns

You can still run this plugin on 11g without the JSON column support.  Simply declare your column as `varchar2` or `clob`. Then use `apex_json.to_xmltype` to convert the JSON to XML and `xmltape` to extract the JSON.

```
select /*+ no_merge */ p.id
     , t.lang
     , t.tl
  from px_projects p
     , xmltable('/json/row' passing apex_json.to_xmltype(p.name_jtl)
        columns
             lang  varchar2(10 char) path 'l'
           , tl    varchar2(50 char) path 'tl'
      ) t
```

You will definitely incur in a performance hit, both from the context switch when you call `apex_json.to_xmltype` and from the conversion itself. However, this may be acceptable in your situation.

You'll also miss out of the JSON constraint on the column, but this is not a concern when using the plugin, only if you manually insert data into the column.


### Issues/Questions
* How do I "install" a new language? — New languages added at a later date will require the `_JTL` columns be *updated* with the new language.
* Removing languages may require data updates also, however, this could be handled by the plugin.
* The `_JTL` column datatype does not match required column size. Columns need to be as large as the desired size times the languages plus the JSON overhead. Use a size `{Required Size} x {# of Languages} + offset`
* Column sizes need to be enforced via APEX Maximum Length field and in the `_VL` views as part of the `JSON_TABLE`.
* Plugin does not perform size validations or validate the correct JSON structure is in place.
* There seems to be an issue in 12.1 and 12.2 when using more than one JSON column. See this [livesql script](https://livesql.oracle.com/apex/livesql/s/dwifcd7pqq1eg64z0jkblyin6) for a test case.  Perhaps I'm doing something wrong, or you have a suggestion. If so, please don't hesitate to raise it as an [Issue](https://github.com/rimblas/jtlitem/issues).

### Pending
* Need to implement `TEXTAREA`, currently all translated items are input boxes.
* The following functionality needs to be tested:
    - Hide
    - Show

## Credits
Thanks to [Insum Solutions](https://insum.ca) for sponsoring this project.

The original concept for using JSON columns to store language is thanks to Bruno Mailloux.<br>
The jQuery widget code based in part on code from, the professor, Dan McGhan.


