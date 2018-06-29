select a.contract_name, a.connector_name, a.send_function_id, a.return_function_id
from tbcn_contract a
where a.send_function_id >=800
or (a.contract_name='NotifyClarify' 
and a.send_function_id >3 )
order by a.contract_name
