--AREA = code
-- Contains script(SQL Statements) for switching a interface from Simulator to JaxWS Real System

--DidntChange
update tbcn_contract set send_function_id = '502' where contract_name = 'NotifyClarify';


UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4160' WHERE (CONTRACT_NAME = 'CancelInstallationWorkOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4340' WHERE (CONTRACT_NAME = 'CancelNetworkAddressReservation');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1210' WHERE (CONTRACT_NAME = 'CheckPortAvailability');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '300' WHERE (CONTRACT_NAME = 'CircuitManagement');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1300' WHERE (CONTRACT_NAME = 'CreateFacilityAssignment');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4170' WHERE (CONTRACT_NAME = 'CreateInstallationWorkOrder');

--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1270' WHERE (CONTRACT_NAME = 'DisconnectService');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1240' WHERE (CONTRACT_NAME = 'ModifyPathStatus');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1220' WHERE (CONTRACT_NAME = 'ModifyPortAssignment');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1260' WHERE (CONTRACT_NAME = 'ModifyService');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '899' WHERE (CONTRACT_NAME = 'NotifyBilling');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4040' WHERE (CONTRACT_NAME = 'NotifyOrderOrProductDetails');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4020' WHERE (CONTRACT_NAME = 'NotifyShipmentSystem');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '800' WHERE (CONTRACT_NAME = 'PricingQuery');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4180' WHERE (CONTRACT_NAME = 'ProcessOrder');

--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1230' WHERE (CONTRACT_NAME = 'PublishAutoDiscoveryResults');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1290' WHERE (CONTRACT_NAME = 'ReserveActivateFacilityAssignment');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4330' WHERE (CONTRACT_NAME = 'ReserveNetworkAddress');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1250' WHERE (CONTRACT_NAME = 'RetrieveCustomerTransportInfo');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4000' WHERE (CONTRACT_NAME = 'RetrieveLocationForAddress');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4010' WHERE (CONTRACT_NAME = 'RetrieveServiceAvailabilityForAddress');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4150' WHERE (CONTRACT_NAME = 'RetrieveTechAvailForInstallation');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1340' WHERE (CONTRACT_NAME = 'SendF1F2Order');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4030' WHERE (CONTRACT_NAME = 'SubmitShipmentOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '4190' WHERE (CONTRACT_NAME = 'UpdateCreditApplication');

--Dsl Disconnect changed in R6
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '3333' WHERE (CONTRACT_NAME = 'DslDisconnect');
--DidntChange
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '1180' WHERE (CONTRACT_NAME = 'RetrieveSubscriptionAccountsForAccountNumber');

-- below update TBCN_CONTRACT to use new R 5.5 Artix clients (real system setting)

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4280 where CONTRACT_NAME = 'RetrieveServiceAreaByPostalCode';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4240 where CONTRACT_NAME = 'CheckCombineEligibility';

--update TBCN_CONTRACT set SEND_FUNCTION_ID = 2100 where CONTRACT_NAME = 'CreateBillingAccount';

--update TBCN_CONTRACT set SEND_FUNCTION_ID = 2130 where CONTRACT_NAME = 'FindCingularAccountsByCustomerAttributes';

--Didnt Change
update TBCN_CONTRACT set SEND_FUNCTION_ID = 2110 where CONTRACT_NAME = 'RetrieveWirelessCreditCheckResult';

--Didnt Change
update TBCN_CONTRACT set SEND_FUNCTION_ID = 2120 where CONTRACT_NAME = 'SubmitWirelessCreditApplication';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4260 where CONTRACT_NAME = 'ReserveWirelessNetworkAddress';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4270 where CONTRACT_NAME = 'DeterminePortabilityStatus';

--update TBCN_CONTRACT set SEND_FUNCTION_ID = 2210 where CONTRACT_NAME = 'CalculateTaxForProductCharges';

--update TBCN_CONTRACT set SEND_FUNCTION_ID = 2200 where CONTRACT_NAME = 'AuthorizeCreditCard';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4220 where CONTRACT_NAME = 'CombineWirelessBill';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4230 where CONTRACT_NAME = 'OrderWireless';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4250 where CONTRACT_NAME = 'FindAvailableNetworkAddressForLocation';


-- R3 new interfaces
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4300 where CONTRACT_NAME = 'ConvertTdmToVoip';
	           
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4310 where CONTRACT_NAME = 'UpdateE911';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4320 where CONTRACT_NAME = 'UpdateDirectoryListing';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4330 where CONTRACT_NAME = 'ReserveNetworkAddress';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4340 where CONTRACT_NAME = 'CancelNetworkAddressReservation';
	
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4350 where CONTRACT_NAME = 'DetermineLocalNumberPortability';

--Didnt Change
update TBCN_CONTRACT set SEND_FUNCTION_ID = 3080 where CONTRACT_NAME = 'SendFacilityAssignmentOrder';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4380 where CONTRACT_NAME = 'SendTNAssignmentOrder';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4390 where CONTRACT_NAME = 'SendActivateTNPortingSubscriptionMsg';

--DidntChange
update TBCN_CONTRACT set SEND_FUNCTION_ID = 3110 where CONTRACT_NAME = 'SendORAUpdate';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4360 where CONTRACT_NAME = 'ReturnAvailableNetworkAddresses';


update TBCN_CONTRACT set SEND_FUNCTION_ID = 4050 where CONTRACT_NAME = 'RetrieveTelcoAndInternetInfo';

--Didnt change
update TBCN_CONTRACT set SEND_FUNCTION_ID  = 880 where CONTRACT_NAME = 'NotifyAmss';

--CR 11439
--Defect 81326 Jan 03 2008
--update TBCN_CONTRACT set SEND_FUNCTION_ID = 3303 where CONTRACT_NAME = 'PublishRGActivation';
--Didnt change
update TBCN_CONTRACT set SEND_FUNCTION_ID = 3400 where CONTRACT_NAME = 'PublishRGActivation';
	

-- R5 New Contracts
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4430 where CONTRACT_NAME = 'RetrieveFulfillmentAvailability';
	
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4440 where CONTRACT_NAME = 'NotifyEXMGR';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4420 where CONTRACT_NAME = 'ActivateTN';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4450 where CONTRACT_NAME = 'ValidateFacility';




--Adding ValidateE911 Contract

UPDATE tbcn_contract
   SET send_function_id = 4410
 WHERE contract_name = 'ValidateE911Address';
 

 
--Adding ReadQuotationInfo Contract  
--Didnt change
UPDATE tbcn_function
   SET class_name = 'amdocs.bl3g.sessions.interfaces.api.QuotationServices',
       function_name = 'getQuote',
       return_type = '[Lamdocs.bl3g.datatypes.QQuoteResponseInfo;',
       connection_string = 'ABPQuotationServices'
 WHERE function_id = 27; 


--R6 NewContracts

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4470 where CONTRACT_NAME = 'SendBroadbandProvisioning';


update TBCN_CONTRACT set SEND_FUNCTION_ID = 4480 where CONTRACT_NAME = 'SendBroadbandProvisioningAck';


-- R7 New Contracts
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4490 where CONTRACT_NAME = 'SendCustomerData';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4510 where CONTRACT_NAME = 'GetWirelessOrderData';

update TBCN_CONTRACT set SEND_FUNCTION_ID = 4500 where CONTRACT_NAME = 'FulfillWirelessOrder';



-- R9 New Contracts
-- GetCpeData, 130 -> 4520
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4520 where CONTRACT_NAME = 'GetCpeData';

-- NotifyAdditionalSystems, 100 -> 4530
update TBCN_CONTRACT set SEND_FUNCTION_ID = 4530 where CONTRACT_NAME = 'NotifyAdditionalSystems';
-- End of R9 New Contracts updates

-- R10 New Contracts

-- GetCreditPolicyStatus, 3361 -> 3360
--Didnt change
update TBCN_CONTRACT set SEND_FUNCTION_ID = 3360 where CONTRACT_NAME = 'GetCreditPolicyStatus';

-- End of R10 New Contracts updates



COMMIT;
