--AREA = code 
-- Contains script(SQL Statements) for switching a interface from REAL SYSTEM to SIMULATOR

update tbcn_contract set send_function_id = '3'where contract_name = 'NotifyClarify';

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'CancelInstallationWorkOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'CancelNetworkAddressReservation');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'CheckPortAvailability');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '310' WHERE (CONTRACT_NAME = 'CircuitManagement');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'CreateFacilityAssignment');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'CreateInstallationWorkOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'DisconnectService');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'ModifyPathStatus');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'ModifyPortAssignment');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'ModifyService');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID=100 , RETURN_FUNCTION_ID=121 WHERE CONTRACT_NAME = 'NotifyBilling';

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'NotifyOrderOrProductDetails');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'NotifyShipmentSystem');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID=130 , RETURN_FUNCTION_ID=131 WHERE CONTRACT_NAME = 'PricingQuery';

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'ProcessOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'PublishAutoDiscoveryResults');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'ReserveActivateFacilityAssignment');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'RetrieveCustomerTransportInfo');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'RetrieveLocationForAddress');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'RetrieveServiceAvailabilityForAddress');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'RetrieveTechAvailForInstallation');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'SendF1F2Order');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'SubmitShipmentOrder');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'UpdateCreditApplication');

--DslDisconnect Updated in R6
UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '100' WHERE (CONTRACT_NAME = 'DslDisconnect');

UPDATE TBCN_CONTRACT SET SEND_FUNCTION_ID = '130' WHERE (CONTRACT_NAME = 'RetrieveTelcoAndInternetInfo');

-- below update TBCN_CONTRACT to ejb simulator mode for new R2.1.5 contracts

update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'RetrieveServiceAreaByPostalCode';
-- 130 <- 2220
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'CheckCombineEligibility';
-- 130 <- 2160
--update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'CreateBillingAccount';
-- 130 <- 2100
--update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'FindCingularAccountsByCustomerAttributes';
-- 130 <- 2130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'RetrieveWirelessCreditCheckResult';
-- 130 <- 2110
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'SubmitWirelessCreditApplication';
-- 130 <- 2120
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'ReserveWirelessNetworkAddress';
-- 130 <- 2180
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'DeterminePortabilityStatus';
-- 130 <- 2190
--update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'CalculateTaxForProductCharges';
-- 130 <- 2210
--update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'AuthorizeCreditCard';
-- 130 <- 2200
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'CombineWirelessBill';
-- 130 <- 2140
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'OrderWireless';
-- 130 <- 2150
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'FindAvailableNetworkAddressForLocation';
-- 130 <- 2170

-- R3 new interfaces
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'ConvertTdmToVoip';
--  3010 -> 130           
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'UpdateE911';
--  3020 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'UpdateDirectoryListing';
--  3030 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'ReserveNetworkAddress';
--  3040 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'CancelNetworkAddressReservation';
--  3050 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'DetermineLocalNumberPortability';
--  3060 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendFacilityAssignmentOrder';
--  3080 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendTNAssignmentOrder';
--  3090 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendActivateTNPortingSubscriptionMsg';
--  3100 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendORAUpdate';
--  3110 -> 100
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'ReturnAvailableNetworkAddresses';
--  3070 -> 100

--CR 11439
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'PublishRGActivation';

-- R5 New Contracts
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'RetrieveFulfillmentAvailability';
--  3314 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'NotifyEXMGR';
--  3315 -> 3305
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'ActivateTN';
--  3313 -> 100

update tbcn_contract set send_function_id  = '3' where contract_name = 'NotifyAmss';


--Adding ValidateE911 Contract

UPDATE tbcn_contract
   SET send_function_id = 3230
 WHERE contract_name = 'ValidateE911Address';
 

 
--Adding ReadQuotationInfo Contract 

UPDATE tbcn_function
   SET class_name = 'amdocs.oms.sbcsimulator.LocalQuotationServices',
       function_name = 'getQuote',
       return_type = '[Lamdocs.oms.simulator.QQuoteResponseInfo;',
       connection_string = 'LocalQuotationSimulator'
 WHERE function_id = 27;

update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'ValidateFacility';
-- 3330 -> 100 

--R6 NewContracts

update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendBroadbandProvisioning';
-- 3337-> 100

update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'SendBroadbandProvisioningAck';
-- 3340-> 100

-- R7 New Contracts

update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'SendCustomerData';
--  3345 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'GetWirelessOrderData';
--  3347 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'FulfillWirelessOrder';
--  3346 -> 130

-- R9 New Contracts
-- GetCpeData, 3354 -> 130
update TBCN_CONTRACT set SEND_FUNCTION_ID = 130 where CONTRACT_NAME = 'GetCpeData';

-- NotifyAdditionalSystems, 3355 -> 100
update TBCN_CONTRACT set SEND_FUNCTION_ID = 100 where CONTRACT_NAME = 'NotifyAdditionalSystems';
-- End of R9 New Contracts updates

-- R10 New Contracts

-- GetCreditPolicyStatus, 3360 -> 3361
update TBCN_CONTRACT set SEND_FUNCTION_ID = 3361 where CONTRACT_NAME = 'GetCreditPolicyStatus';

-- End of R10 New Contracts updates

commit;
