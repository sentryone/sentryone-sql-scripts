/*
will return last blocking chain events per the blockchainversion
*/

;with Blocking as
(
Select  BCG.HostName, 
		BCG.DatabaseName, 
		BCD.SPID, 
		BCD.BlockedBySpid, 
		BCG.ProgramName, 
		BCG.LoginName , 
		BC.BlockChainVersion, 
		BCD.WaitText, 
		BCD.CommandText
from dbo.BlockChainGroup BCG
join dbo.BlockChain BC on BCG.ID = BC.BlockChainGroupID 
join dbo.BlockChainDetail BCD on BC.ID = BCD.BlockChainID 
where BCG.DiscoveryEndTime is null )
select * from Blocking
where Blocking.BlockChainVersion = (Select max(BlockChainVersion) from Blocking) 
order by Blocking.Hostname,Blocking.BlockedBySpid
