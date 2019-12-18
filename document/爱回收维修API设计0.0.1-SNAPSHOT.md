#                              维修API设计

# 创建与变更说明
|版本 | 编辑人 | 编辑日期 | 变更说明 |
| --- | --- | --- | --- |
| 0.0.1-SNAPSHOT | 储骏，华晨 | 2019-12-18 | 是 |初稿 |

# 文档说明
 - 该文档所有请求没有特别描述，默认都是"application/json"格式。
 - TODO:域名后续确认后再补充：
 - 加签验签算法：TODO:cj 后续直接提供工具类和demo

# 两种返参模型
### 通用返参模型
|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| code | Integer | 响应code | 是 |成功编码200，其他编码异常 |
| resultMessage | String | 响应消息 | 否 |当返回200以外编码时，该信息才会存在 |
| data | Object | 具体业务数据 | 否 |具体业务数据,详细内容见各个接口 |

### 通用分页返参模型
|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| code | Integer | 响应code | 是 |成功编码200，其他编码异常 |
| resultMessage | String | 响应消息 | 否 |当返回200以外编码时，该信息才会存在 |
| data | Object | 具体业务数据 | 否 |具体业务数据,详细内容见各个接口 |
| page | Integer | 页数 | 是 |相比通用返参模型增加的参数|
| pageSize | Integer | 每页条数 | 是 |相比通用返参模型增加的参数|
| totalCount | long | 总数 | 是 |相比通用返参模型增加的参数|

# 接口列表

- [创建维修单](#创建维修单)
- [维修单详情](#维修单详情)
- [分页查询上架商品列表接口](#分页查询上架商品列表接口)

----

##  创建维修单

```
POST /repair-order/create
```

JSON POST parameters:

- ` bizType` 业务类型（1:维修）
- `skuList` 维修选项列表
- `pickUpType` 服务方式（1:到店；2:上门）
- `shopId` 门店ID
- `bookingDt` 预约时间
- `customerName` 顾客名称
- `customerMobile` 顾客电话
- `sourceId` 商家ID
- `userKey` 用户key 

`data` in response:

```
{
  "repairOrderNo":"",
  "repairAmount":"400.00",   //维修原价
  "createDt":"2019-12-05 23:09:00"
}
```

## 维修单详情

```
GET /repair-order/orders/{orderNo}
```
query parameters:

```
"sourceId":""  //商家ID
```



`data` in response:

```
{
   "skuList":{
     {
       "value":"4551",
       "name":"边框背板"
     }...
   },
   "productId":"46",
   "productName":"苹果 6s",
   "shopId":"345",
   "shopName":"合生汇店",
   "customerName":"xx",
   "customerMobile":"1522142***232",
   "bookingDt":"2019-12-05 13:10:00",
   "repairAmount":"400.00",
   "pickUpType":1
   "pickUpName":"到店",
   "bizType":1
   "bizTypeName":"维修订单",
   "orderStatus":"sending"
}
```

## 维修项修改

```
POST /repair-order/order/{orderNo}/sku/update
```

JSON POST parameters:

```
 "skuList":"1,2,3"
```

`data` in response:

```
true
```

## 价格修改

```
POST /repair-order/order/{orderNo}/skuAmount/update
```

JSON POST parameters:

```
"amount":"1200.00"
```

`data` in response:

```
true
```

## 确认支付

```
POST /repair-order/order/{orderNo}/confirm-pay
```

`data` in response:

```
true
```

## 取消订单

```
POST /repair-order/order/{orderNo}/cancel
```

JSON POST parameters:

```
{
    "reason":"",
    "type":"1", //1:系统；2:商家
}
```

`data` in response:

```
true
```

## 订单备注

```
POST /repair-order/order/{orderNo}/remark
```

JSON POST parameters:

```
{
    "remark":"",
    "source":""
}
```

`data` in response:

```
{
    "orderStatus":"",
    "remark":""
}
```

## 修改预约时间

```
POST /repair-order/order/{orderNo}/booking/update
```

JSON POST parameters:

```
{
   "bookingDt":"2019-12-01 12:00:00",
   "source":""
}
```

`data` in response:

```
true
```

## 绑定第三方订单号

```
POST /repair-order/bind-third-order
```

JSON POST parameters:

```
{
   "repairOrderNo":"xxx",
   "thridOrderNo":"Xxx"
}
```

`data` in response:

```
true
```



## 维修订单列表

```
GET /repair-order/orders
```

QueryString Params:

```
"userKey":"xxx",
"orderStatus":"xxx",
"shopId":"XXX",
"sourceId":"XXX"
```

`data` in response:

```
{
    {
       "skuList":{
         {
           "value":"4551",
           "name":"边框背板"
         }...
       },
       "productId":"46",
       "productName":"苹果 6s",
       "shopId":"345",
       "shopName":"合生汇店",
       "customerName":"xx",
       "customerMobile":"1522142***232",
       "bookingDt":"2019-12-05 13:10:00",
       "repairAmount":"400.00",
       "pickUpType":1
       "pickUpName":"到店",
       "bizType":1
       "bizTypeName":"维修订单",
       "orderStatus":"sending"
    }...
}
```

### 短信发送

```
POST /repair-foundation/send-message
```

JSON POST parameters:

```
"mobile":"xxxxx",
"message":"xxxxx"
```

`data` in response:

```
true
```

## 分页查询上架商品列表接口

```
POST /openapi/commodities/page-search
```
### 入参

|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| skuIds | Set<Integer> | sku id列表 | 否 | |
| onlineStatus | Byte | 上架状态，0:下架，1:上架| 否 | |
| pageIndex | Integer | 页数 | 是 |从0开始 |
| pageSize | Integer | 每页查询数量 | 是 |默认每页20条 |

### 返参
#### 返参模型
[通用分页返参模型](#通用分页返参模型)

|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| data | List | 商品对象列表 | 否 | |

#### 商品对象
|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| id | Integer | 主键id | 是 | |
| categoryId | Integer | 类目Id | 是||
| categoryName | String | 类目名称 | 是 ||
| brandId | Integer | 品牌ID | 是 ||
| brandName | String | 品牌名称 | 是 ||
| productId | Integer | 品牌名称 | 是 ||
| productName | String | 品牌名称 | 是 ||
| skuId | Integer | sku id | 是 ||
| skuName | String | sku名称 | 是 |名称例如：“iphone x 白色 内屏坏”|
| officialPrice | Integer | 官方售价，单位:分 | 是 ||
| onlineStatus | Byte | 上架状态，0:下架，1:上架 | 是 ||
| createdDt | Date | 创建时间 | 是 ||
| updatedDt | Date | 更新时间 | 是 ||
| propertyOptionValues | List | 属性值对象列表 | 是 |[参考属性值对象](#属性值对象)|

#### 属性值对象
|参数名 | 参数类型 | 参数含义|是否必填 | 说明 |
| --- | --- | --- | --- |---|
| propertyOptionId | Integer | 属性名id | 是 | |
| propertyOptionName | String | 属性名名称 | 是 | |
| propertyOptionType | Integer | 属性类型,1:规格属性,2:维修属性 | 是 |[参考属性类型枚举值](#属性类型枚举值) |
| propertyOptionValueId | Integer | 属性值id | 是 | |
| propertyOptionValueName | String | 属性值名称 | 是 | |

# 通用异常编码与枚举

TODO: 实际开发过程中补充

## 枚举
#### 属性类型枚举值
|属性值 | 属性类型 | 属性含义 |说明 |
| --- | --- | --- | --- |
| 1 | Integer | 规格属性 |   |
| 2 | Integer | 维修属性 |   |