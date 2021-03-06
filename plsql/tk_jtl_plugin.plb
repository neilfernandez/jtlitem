set define off
-- alter session set PLSQL_CCFLAGS='OOS_LOGGER:TRUE';
create or replace package body tk_jtl_plugin
is

/**
 * @module tk_jtl_plugin
 * Functionality to imaplement and item plugin for (Multi-Language Support) MLS
 */

--------------------------------------------------------------------------------
-- TYPES
/**
 * @type 
 */

-- CONSTANTS
/**
 * @constant gc_scope_prefix Standard logger package name
 */
gc_scope_prefix constant VARCHAR2(31) := lower($$PLSQL_UNIT) || '.';



------------------------------------------------------------------------------
/**
 * Render the item as a hidden and display combo.
 * Original concept for using JSON columns to store language: Bruno Mailloux
 *
 * 
 * @issue
 *
 * @author Jorge Rimblas
 * @created September 19, 2016
 * @param p_item Standard plugin parameters
 * @return
 */
function render(
    p_item                in apex_plugin.t_page_item
  , p_plugin              in apex_plugin.t_plugin
  , p_value               in gt_string
  , p_is_readonly         in boolean
  , p_is_printer_friendly in boolean
 )
return apex_plugin.t_page_item_render_result
is

  l_default_language        gt_string;
  l_language                gt_string;
  l_edit_languages          boolean := false;
  l_languages_list          gt_string;
  l_dialog_title            gt_string := p_item.plain_label;
  l_messages                gt_string := p_plugin.attribute_02; -- for MLS messages

  l_postfix           varchar2(8);
  l_idx               number;
  l_count             number;
  l_found             boolean := false;

  l_name              varchar2(255);
  l_display_value     gt_string;
  l_item_type         gt_string;

  l_onload_code       gt_string;
  l_item_jq           gt_string := apex_plugin_util.page_item_names_to_jquery(p_item.name);
  l_item_display      gt_string := p_item.name ||'_DISPLAY';
  -- l_item_display_jq   gt_string := apex_plugin_util.page_item_names_to_jquery(l_item_display);

  l_render_result     apex_plugin.t_page_item_render_result;
  
  l_crlf              char(2) := chr(13)||chr(10);

begin
  apex_debug.message('BEGIN');

  apex_debug.message('p_item.attribute_01 (Default language): %s', p_item.attribute_01);
  apex_debug.message('p_item.attribute_02 (Edit languages): %s', p_item.attribute_02);
  apex_debug.message('p_item.attribute_03 (Item Type): %s', p_item.attribute_03);

  l_default_language := coalesce(apex_plugin_util.replace_substitutions(p_item.attribute_01)
                               , apex_util.get_session_lang);
  l_edit_languages := apex_plugin_util.get_plsql_func_result_boolean(p_item.attribute_02);
  l_languages_list := apex_plugin_util.get_plsql_function_result(p_plugin.attribute_01); -- Enabled Language List
  l_item_type := coalesce(p_item.attribute_03, 'TEXT');


  -- apex_application.g_debug
  apex_debug.message('l_default_language: %s', l_default_language);
  apex_plugin_util.debug_page_item(p_plugin, p_item, p_value, p_is_readonly, p_is_printer_friendly);

  -- Tell APEX that this field is navigable
  l_render_result.is_navigable := true;


  -- get the value for the language
  apex_json.parse(p_value);
  apex_debug.message('parsing: %s', p_value);
  l_count := apex_json.get_count(p_path => '.');
  apex_debug.message('lagunages count: %s', l_count);

  l_idx := 1;
  l_found := false;
  while not l_found and l_idx <= nvl(l_count,0) loop
    l_language := apex_json.get_varchar2(p_path => '[%d].l', p0 => l_idx);
    apex_debug.message('language: %s', l_language);

    if l_language = l_default_language then
      l_display_value := apex_json.get_varchar2(p_path => '[%d].tl', p0 => l_idx);
      apex_debug.message('Translation: %s', l_display_value);
      l_found := true;
    end if;
    l_idx := l_idx + 1;
    
  end loop;

  -- If we didn't find a language match, default to the first entry
  if not l_found then
    -- l_language := l_default_language;
    l_language := apex_json.get_varchar2(p_path => '[%d].l', p0 => 1);
    l_display_value := apex_json.get_varchar2(p_path => '[%d].tl', p0 => 1);
    apex_debug.message('Didn''t find a language match, using the 1st language: %s', l_language);
  end if;

  -- If a page item saves state, we have to call the get_input_name_for_page_item
  -- to render the internal hidden p_arg_names field. It will also return the
  -- HTML field name which we have to use when we render the HTML input field.

  if p_is_readonly or p_is_printer_friendly then
    -- if the item is readonly we will still render a hidden field with
    -- the value so that it can be used when the page gets submitted
    apex_plugin_util.print_hidden_if_readonly(
        p_item_name           => p_item.name,
        p_value               => p_value,
        p_is_readonly         => p_is_readonly,
        p_is_printer_friendly => p_is_printer_friendly );

    apex_plugin_util.print_display_only(
        p_item_name        => p_item.name
      , p_display_value    => l_display_value
      , p_show_line_breaks => false
      , p_escape           => p_item.escape_output
      , p_attributes       => p_item.element_attributes
    );

    -- Tell APEX that this field is NOT navigable
    l_render_result.is_navigable := false;
  else
    l_name := apex_plugin.get_input_name_for_page_item(false);

    -- this hidden item contains the full JSON column content (all languages!)
    sys.htp.p('
      <input type="hidden" '
         || 'id="' || p_item.name || '" '
         || 'name="' || l_name || '" '
         || 'value="' || apex_plugin_util.escape(p_value => p_value, p_escape => p_item.escape_output) || '" '
         || '/>'
    );

    -- now render the visible element
    sys.htp.p(
        '<fieldset id="' || p_item.name || '_fieldset" class="jtlitem-controls'
         || case when l_item_type = 'TEXTAREA' then ' textarea' end 
         || '" tabindex="-1">');

    if l_item_type = 'TEXT' then
      sys.htp.prn(
          '<input type="text" id="' || l_item_display || '" '
               || 'value="'|| apex_plugin_util.escape(p_value => l_display_value, p_escape => p_item.escape_output) || '" '
               || 'size="' || p_item.element_width||'" '
               || 'maxlength="'||p_item.element_max_length||'" '
               || 'data-lang="' || sys.htf.escape_sc(l_language) || '" '
               || 'class="text_field apex-item-text jtlitem ' || p_item.element_css_classes || '"'
               || p_item.element_attributes ||' />' );
    else
      -- Textareas don't use a value attribute, instead they contain their value 
      -- in between the tags. Therefore, make sure not to add any spaces or other
      -- characters that are not part of the value.
      sys.htp.prn(
          '<textarea id="' || l_item_display || '" wrap="virtual" style="resize: both;" '
               || 'data-lang="' || sys.htf.escape_sc(l_language) || '" '
               || 'class="textarea apex-item-textarea jtlitem ' || p_item.element_css_classes || '"'
               || 'maxlength="'||p_item.element_max_length||'" '
               || 'cols="' || p_item.element_width||'" '
               || 'rows="' || p_item.element_height||'" '
               -- || 'maxlength="'||p_item.element_max_length||'" '
               || p_item.element_attributes ||' >'
               || apex_plugin_util.escape(p_value => l_display_value, p_escape => p_item.escape_output)
       || '</textarea>');
    end if;

    if l_edit_languages then
      sys.htp.p('<button type="button" class="jtlitem-modal-open t-Button">' || l_crlf
             || '  <span class="t-Icon fa fa-globe"></span>' || l_crlf
             || '</button>' || l_crlf
             );
    end if;

    -- Close fieldset.  Note that the textarea should have a fieldset regardless 
    -- of the modal control button
    sys.htp.p (
        ' </fieldset>');
    
  end if;

  apex_javascript.add_onload_code (
      p_code => '$("' || l_item_jq || '").jtl_item({' || l_crlf
                      || apex_javascript.add_attribute('lang', l_language, true, true) || l_crlf
                      || apex_javascript.add_attribute('lang_codes', l_languages_list, false, true) || l_crlf
                      || apex_javascript.add_attribute('messages', l_messages, false, true) || l_crlf
                      || apex_javascript.add_attribute('itemType', l_item_type, false, true) || l_crlf
                      || apex_javascript.add_attribute('dialogTitle', l_dialog_title, false, false) || l_crlf
             || '});'
            );


  l_render_result.is_navigable := true;
  return l_render_result;

  exception
    when OTHERS then
      apex_debug.error('Unhandled Exception');
      raise;
end render;




/**
 * Perform validations on the submitted data:
 *  - Ensure the data is JSON format
 *  - Ensure the JSON format is of the expected form
 *
 *
 * @example
 * 
 * @issue
 *
 * @author Jorge Rimblas
 * @created October 7, 2016
 * @param
 * @return
 */
function validate (
   p_item   in apex_plugin.t_page_item
 , p_plugin in apex_plugin.t_plugin
 , p_value  in varchar2
)
return apex_plugin.t_page_item_validation_result
is
  l_result apex_plugin.t_page_item_validation_result;

  l_default_language  gt_string;
  l_languages_list    gt_string;
  l_language          gt_string;
  l_display_value     gt_string;
  l_error_suffix      gt_string;

  l_idx               number;
  l_count             number;
  l_found_empty       boolean := false;

begin

  apex_debug.message('BEGIN');

  l_default_language := coalesce(apex_plugin_util.replace_substitutions(p_item.attribute_01)
                               , apex_util.get_session_lang);
  l_languages_list := apex_plugin_util.get_plsql_function_result(p_plugin.attribute_01); -- Enabled Language List

  apex_json.parse(p_value);
  apex_debug.message('parsing: %s', p_value);
  l_count := apex_json.get_count(p_path => '.');
  apex_debug.message('lagunages count: %s', l_count);

  -- The item is required, check the "tl" attributes to see if the value is present
  if p_item.is_required then
    apex_debug.message('p_item.is_required = true', l_count);
    l_idx := 1;
    l_found_empty := false;
    -- loop through all the languages or until we find an empty one.
    while not l_found_empty and l_idx <= nvl(l_count,0) loop
      -- get the current language
      l_language := apex_json.get_varchar2(p_path => '[%d].l', p0 => l_idx);
      -- get the translation value for the language
      l_display_value := apex_json.get_varchar2(p_path => '[%d].tl', p0 => l_idx);

      apex_debug.message('language: %s', l_language);

      if l_display_value is null then
        -- this one is null, so we will return a required value error
        l_found_empty := true;
        if l_language = l_default_language then
          apex_debug.message('The current language is null');
          l_error_suffix := '';
        else
          -- Hmmm, the language that is null is NOT the one displayed to the user
          -- add the language code as a prefix to the error.
          apex_debug.message('A different language is null');
          l_error_suffix := '(' || l_language || ')';
        end if;
      end if;
      l_idx := l_idx + 1;
      
    end loop;

  end if;

  if l_found_empty then
    -- Define APEX.PAGE_ITEM_IS_REQUIRED in your language.
    l_result.message := wwv_flow_lang.system_message('APEX.PAGE_ITEM_IS_REQUIRED');
    -- if l_result.message = 'APEX.PAGE_ITEM_IS_REQUIRED' then
    --   -- message not defined yet
    --   l_result.message := apex_lang.message('#LABEL# must have some value.');
    -- end if;
    -- add the language suffix, if the error doesn't apply to the language being displayed.
    l_result.message := l_result.message || l_error_suffix;
  else
    l_result.message := '';
  end if;

  return l_result;

exception
  when apex_json.e_parse_error then
    -- Somehow we don't have valid JSON in our item.
    -- This is more critical for 11g where we don't have "is json" constraints
    l_result.message := 'The JSON structure for #LABEL# is invalid.';
    return l_result;

end validate;





/**
 * Convert a `tab_lang_type` array to JSON format of the form:
 * ```json
 *  [
 *   {"l":"en","tl":"Name"},
 *   {"l":"fr","tl":"Nom - Français"},
 *   {"l":"es","tl":"Nombre - Español"}
 *  ]
 * ```
 *
 *
 * @example
 * 
 * @issue
 *
 * @author Jorge Rimblas
 * @created October 10, 2016
 * @param p_tab tab_lang_type
 * @return clob JSON object
 */
function output_lang_tab(p_tab in out nocopy tab_lang_type)
  return clob
is
  $IF $$OOS_LOGGER $THEN
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'output_lang_tab';
  l_params logger.tab_param;
  $END

  l_output clob;
begin
  $IF $$OOS_LOGGER $THEN
  -- logger.append_param(l_params, 'p_param1', p_param1);
  logger.log('START', l_scope, null, l_params);
  $END
  
  apex_json.initialize_clob_output;
  apex_json.open_array;   -- [
  for i in 1 .. p_tab.count loop
    apex_json.open_object;   -- {
    apex_json.write('l',  p_tab(i).code, true); -- "l":  "lang_code"
    apex_json.write('tl', p_tab(i).tl, true);   -- "tl": "translation"
    apex_json.close_object;   -- }
  end loop;
  apex_json.close_array;  -- ]
  
  l_output := apex_json.get_clob_output;
  apex_json.free_output;  

  return l_output;
  
  -- exception
  --   when OTHERS then
  --     logger.log_error('Unhandled Exception', l_scope, null, l_params);
  --     raise;
end output_lang_tab;





/**
 * Given a JSON string (p_value) return the value of the language defined by code (p_l)
 *
 *
 * @example
 * tk_jtl_plugin.get_tl_value(:P3_NAME_JTL, :SESSION_LANG) is not null
 *
 * @issue
 *
 * @author Jorge Rimblas
 * @created October 11, 2016
 * @param p_value JSON MLS structure
 * @param p_l language code (ie. 'es', 'fr', ...)
 * @return New value as varchar2
 */
function get_tl_value(
    p_value in varchar2
  , p_l     in lang_code default apex_application.g_flow_language
)
return varchar2
is
  $IF $$OOS_LOGGER $THEN
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'get_tl_value';
  l_params logger.tab_param;
  $END

  j        apex_json.t_values;
  l_paths  apex_t_varchar2;
  l_count  number;

  l_code   lang_code;

  l_output gt_string;
begin
  $IF $$OOS_LOGGER $THEN
  -- logger.append_param(l_params, 'p_param1', p_param1);
  logger.log('START', l_scope, null, l_params);
  $END

  apex_json.parse(j, p_value);
  l_count := apex_json.get_count(p_path=>'.',p_values=>j);

  -- loop for all languages and remove the p_l language
  for i in 1 .. l_count loop
    l_code := apex_json.get_varchar2(p_path=>'[%d].l', p0=> i, p_values=>j);
    if l_code = p_l then
      l_output := apex_json.get_varchar2(p_path=>'[%d].tl',p0=> i, p_values=>j);
      exit;
    end if;
  end loop;

  return l_output;
  
exception
  when OTHERS then
    $IF $$OOS_LOGGER $THEN
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    $END
    raise;
end get_tl_value;





/**
 * Given a JSON string (p_value) update the corresponding language code (p_l)
 * with a new translation (p_tl)
 *
 *
 * @example
 * update px_projects
 *    set name_jtl = tk_jtl_plugin.set_tl(name_jtl, 'en', 'New value')
 * where id = 21;
 * 
 * @issue No error is returned if the p_l value doesn't exist
 *
 * @author Jorge Rimblas
 * @created October 10, 2016
 * @param p_value JSON MLS structure
 * @param p_l language code (ie. 'es', 'fr', ...)
 * @param p_tl New translated value
 * @return New JSON MSL value
 */
function set_tl(
    p_value in varchar2
  , p_l     in lang_code default apex_application.g_flow_language
  , p_tl    in varchar2
)
return varchar2
is
  $IF $$OOS_LOGGER $THEN
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'set_tl';
  l_params logger.tab_param;
  $END

  j        apex_json.t_values;
  l_paths  apex_t_varchar2;
  l_count  number;

  l_tab    tab_lang_type := tab_lang_type();

  l_output clob;
begin
  $IF $$OOS_LOGGER $THEN
  -- logger.append_param(l_params, 'p_param1', p_param1);
  logger.log('START', l_scope, null, l_params);
  $END

  if p_value is null then
    raise_application_error(-20001, 'Cannot set a language on an empty JSON string.');
  end if;

  apex_json.parse(j, p_value);
  l_count := apex_json.get_count(p_path=>'.',p_values=>j);

  -- loop for all languages. When we find the p_l language replace it with p_tl
  for i in 1 .. l_count loop
    l_tab.extend;
    l_tab(i).code  := apex_json.get_varchar2(p_path=>'[%d].l', p0=> i, p_values=>j);
    if l_tab(i).code = p_l then
      l_tab(i).tl := p_tl;
    else
      l_tab(i).tl := apex_json.get_varchar2(p_path=>'[%d].tl',p0=> i, p_values=>j);
    end if;
  end loop;

  l_output := output_lang_tab(l_tab);
  return l_output;
  
exception
  when OTHERS then
    $IF $$OOS_LOGGER $THEN
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    $END
    raise;
end set_tl;





/**
 * Given a JSON string (p_value) add a new language as defined by code (p_l)
 * and translation (p_tl) at the end of the JSON MLS structure
 *
 *
 * @example
 * update px_projects
 *    set name_jtl = tk_jtl_plugin.add_tl(name_jtl, 'en', 'New value')
 * where id = 21;
 * 
 * @issue
 *
 * @author Jorge Rimblas
 * @created October 10, 2016
 * @param p_value JSON MLS structure
 * @param p_l language code (ie. 'es', 'fr', ...)
 * @param p_tl New translated value
 * @return New JSON MSL value
 */
function add_tl(
    p_value in varchar2
  , p_l     in lang_code default apex_application.g_flow_language
  , p_tl    in varchar2
)
return varchar2
is
  $IF $$OOS_LOGGER $THEN
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'add_tl';
  l_params logger.tab_param;
  $END

  j        apex_json.t_values;
  l_paths  apex_t_varchar2;
  l_count  number;

  l_tab    tab_lang_type := tab_lang_type();

  l_output clob;
begin
  $IF $$OOS_LOGGER $THEN
  -- logger.append_param(l_params, 'p_param1', p_param1);
  logger.log('START', l_scope, null, l_params);
  $END

  if p_value is not null then
    apex_json.parse(j, p_value);
    l_count := apex_json.get_count(p_path=>'.',p_values=>j);

    -- loop for all languages. 
    for i in 1 .. l_count loop
      l_tab.extend;
      l_tab(i).code := apex_json.get_varchar2(p_path=>'[%d].l', p0=> i, p_values=>j);
      l_tab(i).tl := apex_json.get_varchar2(p_path=>'[%d].tl',p0=> i, p_values=>j);
      if l_tab(i).code = p_l then
        raise_application_error(-20000, 'Language [' || p_l || '] already exists.');
      end if;
    end loop;
  end if;

  -- Add the new language
  l_tab.extend;
  l_tab(l_tab.last).code := p_l;
  l_tab(l_tab.last).tl := p_tl;

  l_output := output_lang_tab(l_tab);
  return l_output;
  
exception
  when OTHERS then
    $IF $$OOS_LOGGER $THEN
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    $END
    raise;
end add_tl;





/**
 * Given a JSON MLS string (p_value) remove a language as defined by code (p_l)
 *
 *
 * @example
 * update px_projects
 *    set name_jtl = tk_jtl_plugin.remove_tl(name_jtl, 'en', 'New value')
 * where id = 21;
 * 
 * @issue
 *
 * @author Jorge Rimblas
 * @created October 10, 2016
 * @param p_value JSON MLS structure
 * @param p_l language code (ie. 'es', 'fr', ...)
 * @return New JSON MSL value
 */
function remove_tl(
    p_value in varchar2
  , p_l     in lang_code default apex_application.g_flow_language
)
return varchar2
is
  $IF $$OOS_LOGGER $THEN
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'remove_tl';
  l_params logger.tab_param;
  $END

  j        apex_json.t_values;
  l_paths  apex_t_varchar2;
  l_count  number;

  l_tab    tab_lang_type := tab_lang_type();
  l_code   lang_code;

  l_output clob;
begin
  $IF $$OOS_LOGGER $THEN
  -- logger.append_param(l_params, 'p_param1', p_param1);
  logger.log('START', l_scope, null, l_params);
  $END

  apex_json.parse(j, p_value);
  l_count := apex_json.get_count(p_path=>'.',p_values=>j);

  -- loop for all languages and remove the p_l language
  for i in 1 .. l_count loop
    l_code := apex_json.get_varchar2(p_path=>'[%d].l', p0=> i, p_values=>j);
    if l_code = p_l then
      -- found it, do nothing so it gets removed
      null;
    else
      l_tab.extend;
      l_tab(l_tab.last).code := l_code;
      l_tab(l_tab.last).tl := apex_json.get_varchar2(p_path=>'[%d].tl',p0=> i, p_values=>j);
    end if;
  end loop;

  l_output := output_lang_tab(l_tab);
  return l_output;
  
exception
  when OTHERS then
    $IF $$OOS_LOGGER $THEN
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    $END
    raise;
end remove_tl;




end tk_jtl_plugin;
/

