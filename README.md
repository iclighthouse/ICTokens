# ICTokens

**Website:** [http://ictokens.com](http://ictokens.com/)  
**Canister id:**  nts5d-vaaaa-aaaak-aabbq-cai  
**ModuleHash:** 9cbf07e30dc0849fa44e88827d74b3a4c91131f91416ca2bc5477f1dffb1f0f2

**ICTokens Scan**  
**Website:** [http://scan.ictokens.com](http://scan.ictokens.com/)(building)  
**Canister id:**  oearr-eyaaa-aaaak-aabja-cai  
**ModuleHash:** 63a8040a5b7650a4333214f281a1edf267d2778e0de9312890182f6c7f97e2dd

## 简介（Overview）

ICTokens是ICLighthouse旗下一个资产通证化（Asset Tokenization）平台，Token基于[DRC20标准](https://github.com/iclighthouse/DRC_standards/tree/main/DRC20)。发行方可以一键发行Token并进行管理；用户可以Star喜欢的Token，根据token的综合得分获得推荐token列表。ICTokens还提供了一个基于[DRC202](https://github.com/iclighthouse/DRC_standards/tree/main/DRC202)标准的Token区块链浏览器（[ICTokens Scan](http://scan.ictokens.com)），解决了IC网络上没有统一查看token交易记录的难题。

## 工作原理 （How it works）

![image](ictokens.png)

一个创始人通过ICTokens可以一键发行token，遵循DRC20标准，他可以获得该token的控制权。每创建一个token，要被收取100 ICL平台治理代币。ICTokens提供了管理token的UI界面，他可以管理自己的token。

用户可以在ICTokens查询token列表，该列表通过评分进行排序，评分依据是用户Star数量和平台的推荐值进行综合计算。   
如果用户需要关注某个token，他可以点击Star（每次Star需要发送1 ICL平台治理代币），将该token加入关注列表。

ICTokens的另一项服务提供一个公共的Token交易记录浏览器（ICTokens Scan），遵循DRC202标准。ICTokens Scan支持多Token存储交易历史记录，作为Token的历史数据持久化解决方案。DRC202的Token交易记录存储机制是通过一个入口合约Proxy代理存储，Proxy根据实际存储需求创建Bucket（一个Bucket存满后会创建一个新的Bucket），然后将交易记录压缩后存入Bucket。需要查询Token的交易记录时，先从Proxy查询到该记录保存在哪个Bucket中（使用了BloomFilter技术进行路由），再从Bucket取出交易记录数据。

![image](drc202.png)

## 使用（Usage）

### 创建一个Token

**Step1:** 登陆ICLighthouse首页，创建或导入用户。进入首页点击左侧菜单栏ICTokens按钮，进入token管理页面。 

**Step2:** 用户在ICLighthouse上approve给ICTokens(TokenFactory)容器 xxx ICL（大于100）。

**Step3:** 填写自己的token名称，发行量等信息，点击创建并等待返回token的canister id。

### 资源

**DRC20**: https://github.com/iclighthouse/DRC_standards/tree/main/DRC20

**DRC202**: https://github.com/iclighthouse/DRC_standards/tree/main/DRC202

