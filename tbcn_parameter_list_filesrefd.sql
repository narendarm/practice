SELECT a.function_id, a.obtain_function_id,
       a.obtain_value, a.application_id
  FROM tbcn_parameter a
  where a.obtain_value like '%file%'
  /* where a.obtain_value like '%http%' */
  
  
