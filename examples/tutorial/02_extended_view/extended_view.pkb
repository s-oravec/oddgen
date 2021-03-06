CREATE OR REPLACE PACKAGE BODY extended_view AS
   /*
   * Copyright 2015-2016 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
   *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *     http://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   */

   --
   -- parameter constants, used as labels in the generate dialog
   --
   co_select_star   CONSTANT string_type := 'Select * ?';
   co_view_suffix   CONSTANT string_type := 'View suffix';
   co_order_columns CONSTANT string_type := 'Order columns?';

   --
   -- get_name - override OGDEMO.EXTENDED_VIEW
   --
   FUNCTION get_name RETURN VARCHAR2 IS
   BEGIN
      RETURN 'Extended 1:1 View Generator';
   END get_name;

   --
   -- get_description - override OGDEMO.EXTENDED_VIEW
   --
   FUNCTION get_description RETURN VARCHAR2 IS
   BEGIN
      RETURN 'Generates a 1:1 view based on an existing table and various generator parameters.';
   END get_description;

   --
   -- get_object_types - override [Tables, Views]
   --
   FUNCTION get_object_types RETURN t_string IS
   BEGIN
      RETURN NEW t_string('TABLE');
   END get_object_types;

   --
   -- get_object_names - override query for 'TABLE' returning object names using initcap()
   --
   FUNCTION get_object_names(in_object_type IN VARCHAR2) RETURN t_string IS
      l_object_names t_string;
   BEGIN
      SELECT initcap(object_name) AS object_name
        BULK COLLECT
        INTO l_object_names
        FROM user_objects
       WHERE object_type = in_object_type
             AND generated = 'N'
       ORDER BY object_name;
      RETURN l_object_names;
   END get_object_names;

   --
   -- get_params - configure additional parameters beside object_type and object_name
   --
   FUNCTION get_params(in_object_type IN VARCHAR2, in_object_name IN VARCHAR2)
      RETURN t_param IS
      l_params t_param;
   BEGIN
      l_params(co_select_star) := 'No';
      l_params(co_view_suffix) := '_v';
      l_params(co_order_columns) := 'No';
      RETURN l_params;
   END get_params;

   --
   -- get_ordered_params - override default sort order (by name)
   --
   FUNCTION get_ordered_params(in_object_type IN VARCHAR2, in_object_name IN VARCHAR2)
      RETURN t_string IS
   BEGIN
      RETURN NEW t_string(co_select_star, co_view_suffix, co_order_columns);
   END get_ordered_params;

   --
   -- get_lov
   --
   FUNCTION get_lov(in_object_type IN VARCHAR2,
                    in_object_name IN VARCHAR2,
                    in_params      IN t_param) RETURN t_lov IS
      l_lov t_lov;
   BEGIN
      IF in_params(co_select_star) = 'Yes' THEN
         l_lov(co_order_columns) := NEW t_string('No');
      ELSE
         l_lov(co_order_columns) := NEW t_string('Yes', 'No');
      END IF;
      IF in_params(co_order_columns) = 'Yes' THEN
         l_lov(co_select_star) := NEW t_string('No');
      ELSE
         l_lov(co_select_star) := NEW t_string('Yes', 'No');
      END IF;
      RETURN l_lov;
   END get_lov;

   --
   -- generate - signature used by oddgen for SQL Developer
   --
   FUNCTION generate(in_object_type IN VARCHAR2,
                     in_object_name IN VARCHAR2,
                     in_params      IN t_param) RETURN CLOB IS
      l_templ        CLOB := 'CREATE OR REPLACE VIEW ${view_name} AS
   SELECT ${column_names}
     FROM ${table_name};';
      l_clob         CLOB;
      l_view_name    string_type;
      l_column_names string_type;
      l_table_name   string_type;
   BEGIN
      -- prepare placeholder column_names
      IF in_params(co_select_star) = 'Yes' THEN
         l_column_names := '*';
      ELSE
         FOR l_rec IN (SELECT column_name
                         FROM user_tab_columns
                        WHERE table_name = upper(in_object_name)
                        ORDER BY CASE
                                    WHEN in_params(co_order_columns) = 'Yes' THEN
                                     column_name
                                    ELSE
                                     to_char(column_id, '99999')
                                 END)
         LOOP
            IF l_column_names IS NOT NULL THEN
               l_column_names := l_column_names || ', ';
            END IF;
            l_column_names := l_column_names || lower(l_rec.column_name);
         END LOOP;
      END IF;
      -- prepare placeholder table_name
      l_table_name := lower(in_object_name);
      -- prepare placeholder view_name
      l_view_name := l_table_name || lower(in_params(co_view_suffix));
      -- produce final clob, replace placeholder in template
      l_clob := REPLACE(l_templ, '${column_names}', l_column_names);
      l_clob := REPLACE(l_clob, '${view_name}', l_view_name);
      l_clob := REPLACE(l_clob, '${table_name}', l_table_name);
      RETURN l_clob;
   END generate;

   --
   -- generate - signature accessible from plain SQL (not used by oddgen)
   --
   FUNCTION generate(in_object_type   IN VARCHAR2,
                     in_object_name   IN VARCHAR2,
                     in_select_star   IN VARCHAR2 DEFAULT 'No',
                     in_view_suffix   IN VARCHAR2 DEFAULT '_v',
                     in_order_columns IN VARCHAR2 DEFAULT 'No') RETURN CLOB IS
      l_params t_param;
   BEGIN
      l_params(co_select_star) := in_select_star;
      l_params(co_view_suffix) := in_view_suffix;
      l_params(co_order_columns) := in_order_columns;
      RETURN generate(in_object_type, in_object_name, l_params);
   END generate;

END extended_view;
/
