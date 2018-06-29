--AREA = ref
-- date: 09/18/2008
-- author : Gauresh Lad (gc3781)
-- Contains script(SQL Statements) for switching a interface from Simulator to Real System

-- R9 New Contracts
update TBDIFF_MECH_POLICY set DIFF_POLICY = 'AP' where INTERFACE_NAME = 'GetCpeData';
-- End of R9 New Contracts updates