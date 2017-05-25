DECLARE @runtime VARCHAR(1000)
DECLARE @topology VARCHAR(1000)
SET @runtime =
'<?xml version="1.0" ?>
<runtime xmlns="http://schemas.lawson.com/grid/configuration_v3">
    <bindings />
    <sessionProviders developer="true" />
    <routers><router name="Default Router" host="localhost" httpsPort="50000" httpPort="50001" /></routers>
    <contextRoots />
    <propertySettings />
</runtime>'
SET @topology =
'<?xml version="1.0" ?>
<topology xmlns="http://schemas.lawson.com/grid/configuration_v3">
    <hosts>
        <host name="localhost" address="127.0.0.1" gridAgentPort="50003" />
    </hosts>
    <registry host="localhost" port="50004" />
	<administrativeRouter host="localhost" port="50005" webStartPort="50006" httpsPort="50007" />
</topology>'
DELETE FROM GRIDCONF
INSERT INTO GRIDCONF (GRID, TYPE, NAME, TS, DATA, SEQID) VALUES ('Grid', 'runtime' , 'null', 0, CONVERT(varbinary(max), @runtime), 0)
INSERT INTO GRIDCONF (GRID, TYPE, NAME, TS, DATA, SEQID) VALUES ('Grid', 'topology' , 'null', 0, CONVERT(varbinary(max), @topology), 0)
