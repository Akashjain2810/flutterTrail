import 'dart:async';
import 'dart:convert';

import 'package:eshop/Model/Order_Model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart';

import 'Helper/AppBtn.dart';
import 'Helper/Color.dart';
import 'Helper/Constant.dart';
import 'Helper/Session.dart';
import 'Helper/String.dart';
import 'Login.dart';
import 'OrderDetail.dart';

class MyOrder extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return StateMyOrder();
  }
}

List<OrderModel> orderList = [];
List<OrderModel> searchList = [];

List<OrderModel> orderProgressList = [];
int pos = 0;

class StateMyOrder extends State<MyOrder> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  String searchText;
  Animation buttonSqueezeanimation;
  AnimationController buttonController;
  bool _isNetworkAvail = true;
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    orderList.clear();
    searchList.clear();
    getOrder();
    buttonController = new AnimationController(
        duration: new Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = new Tween(
      begin: deviceWidth * 0.7,
      end: 50.0,
    ).animate(new CurvedAnimation(
      parent: buttonController,
      curve: new Interval(
        0.0,
        0.150,
      ),
    ));
    _controller.addListener(() {
      searchOperation(_controller.text);
      if (mounted) setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    buttonController.dispose();
    super.dispose();
  }

  Future<void> searchOperation(String searchText) async {
    searchList.clear();
    for (int i = 0; i < orderList.length; i++) {
      for (int j = 0; j < orderList[i].itemList.length; j++) {
        OrderModel map = orderList[i];

        if (map.id.toLowerCase().contains(searchText) ||
            map.itemList[j].name.toLowerCase().contains(searchText)) {
          searchList.add(map);
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<Null> _playAnimation() async {
    try {
      await buttonController.forward();
    } on TickerCanceled {}
  }

  Widget noInternet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noIntImage(),
          noIntText(context),
          noIntDec(context),
          AppBtn(
            title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
            btnAnim: buttonSqueezeanimation,
            btnCntrl: buttonController,
            onBtnSelected: () async {
              _playAnimation();

              Future.delayed(Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  getOrder();
                } else {
                  await buttonController.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.lightWhite,
      appBar: getAppBar(getTranslated(context, 'MY_ORDERS_LBL'), context),
      body: _isNetworkAvail
          ? _isLoading
              ? shimmer()
              : RefreshIndicator(
                  key: _refreshIndicatorKey,
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 35,
                              padding: EdgeInsetsDirectional.only(
                                  start: 5.0, end: 5.0),
                              child: TextField(
                                controller: _controller,
                                onChanged: (value) {
                                  if (_controller.text.trim().isNotEmpty) {
                                    searchOperation(_controller.text);
                                  } else {
                                    if (mounted) setState(() {});
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: colors.white,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(15.0, 9.0, 0, 9.0),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SvgPicture.asset(
                                      'assets/images/search.svg',
                                      color: colors.primary,
                                      height: 10,
                                    ),
                                  ),
                                  hintText: getTranslated(
                                      context, 'FIND_ORDER_ITEMS_LBL'),
                                  hintStyle: TextStyle(
                                      color: colors.fontColor.withOpacity(0.3),
                                      fontWeight: FontWeight.normal),
                                  border: new OutlineInputBorder(
                                    borderSide: BorderSide(
                                      width: 0,
                                      style: BorderStyle.none,
                                    ),
                                  ),
                                ),
                              )),
                          searchList.length == 0
                              ? Center(
                                  child: Text(getTranslated(context, 'noItem')))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsetsDirectional.only(top: 5.0),
                                  itemCount: searchList.length,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    if (searchList[index] != null &&
                                        searchList[index].itemList.length > 0) {
                                      OrderItem orderItem =
                                          searchList[index].itemList[0];
                                      return productItem(index, orderItem);
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                        ],
                      ),
                    ),
                  ))
          : noInternet(context),
    );
  }

  Future<Null> _refresh() {
    if (mounted)
      setState(() {
        _isLoading = true;
      });
    orderList.clear();
    searchList.clear();
    return getOrder();
  }

  Future<Null> getOrder() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (CUR_USERID != null) {
          var parameter = {USER_ID: CUR_USERID};

          Response response =
              await post(getOrderApi, body: parameter, headers: headers)
                  .timeout(Duration(seconds: timeOut));

          var getdata = json.decode(response.body);
          bool error = getdata["error"];
          //  String msg = getdata["message"];
          searchList.clear();
          orderList.clear();

          if (!error) {
            var data = getdata["data"];
            orderList = (data as List)
                .map((data) => new OrderModel.fromJson(data))
                .toList();
          }

          searchList.addAll(orderList);
          if (mounted) if (mounted)
            setState(() {
              _isLoading = false;
            });
        } else {
          if (mounted) if (mounted)
            setState(() {
              _isLoading = false;
              //msg = goToLogin;
            });

          Future.delayed(Duration(seconds: 1)).then((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Login()),
            );
          });
        }
      } on TimeoutException catch (_) {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
        setSnackbar(getTranslated(context, 'somethingMSg'));
      }
    } else {
      if (mounted) if (mounted)
        setState(() {
          _isNetworkAvail = false;
          _isLoading = false;
        });
    }

    return null;
  }

  getSearch(String searchText) {
    searchList.clear();
    for (int i = 0; i < orderList.length; i++) {
      for (int j = 0; j < orderList[i].itemList.length; j++) {
        OrderModel map = orderList[i];

        if (map.id.toLowerCase().contains(searchText) ||
            map.itemList[j].name.toLowerCase().contains(searchText)) {
          searchList.add(map);
        }
      }
    }

    if (mounted) setState(() {});
  }

  setSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
      content: new Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.black),
      ),
      backgroundColor: colors.white,
      elevation: 1.0,
    ));
  }

  productItem(int index, OrderItem orderItem) {
    String sDate = orderItem.listDate.last;
    String proStatus = orderItem.listStatus.last;
    if (proStatus == 'received') {
      proStatus = 'order placed';
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.all(5.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(children: <Widget>[
              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Hero(
                    tag: "$index${orderItem.id}",
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7.0),
                      child: FadeInImage(
                        fadeInDuration: Duration(milliseconds: 150),
                        image: NetworkImage(orderItem.image),
                        height: 90.0,
                        width: 90.0,
                        fit: extendImg ? BoxFit.fill : BoxFit.contain,
                        // errorWidget:(context, url,e) => placeHolder(90) ,
                        placeholder: placeHolder(90),
                      ),
                    )),
                Expanded(
                    flex: 9,
                    child: Padding(
                        padding:
                            EdgeInsetsDirectional.only(start: 5.0, end: 5.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                "$proStatus on $sDate",
                                style: Theme.of(context)
                                    .textTheme
                                    .subtitle2
                                    .copyWith(color: colors.lightBlack),
                              ),
                              Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 10.0),
                                  child: Text(
                                    orderItem.name +
                                        "${orderList[index].itemList.length > 1 ? " and more items" : ""} ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .subtitle2
                                        .copyWith(
                                            color: colors.lightBlack2,
                                            fontWeight: FontWeight.normal),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                            ]))),
                Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.primary,
                  size: 15,
                )
              ]),
            ])),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => OrderDetail(model: searchList[index])),
          );
          if (mounted)
            setState(() {
              _isLoading = true;
            });

          getOrder();
        },
      ),
    );
  }
}
