/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';

class AppsService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final FLauncherDatabase _database;
  bool _initialized = false;

  List<App> _applications = [];
  List<CategoryWithApps> _categoriesWithApps = [];

  bool get initialized => _initialized;

  List<App> get applications => UnmodifiableListView(_applications);

  List<CategoryWithApps> get categoriesWithApps => _categoriesWithApps
      .map((item) => CategoryWithApps(item.category, UnmodifiableListView(item.applications)))
      .toList(growable: false);

  AppsService(this._fLauncherChannel, this._database) {
    _init();
  }

  Future<void> _init() async {
    await _refreshState(shouldNotifyListeners: false);
    if (_database.wasCreated) {
      await _initDefaultCategories();
    }
    _fLauncherChannel.addAppsChangedListener((event) async {
      switch (event["action"]) {
        case "PACKAGE_ADDED":
        case "PACKAGE_CHANGED":
          await _database.persistApps([_buildAppCompanion(event["activitiyInfo"])]);
          final tvAppsCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "所有应用");
          await addToCategory((await _database.getAppByPackage(event["activitiyInfo"]["packageName"]))[0], tvAppsCategory, shouldNotifyListeners: true);
          break;
        case "PACKAGES_AVAILABLE":
          await _database.persistApps((event["activitiesInfo"] as List<dynamic>).map(_buildAppCompanion).toList());
          break;
        case "PACKAGE_REMOVED":
          await _database.deleteApps([event["packageName"]]);
          break;
      }
      _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      _applications = await _database.listApplications();
      notifyListeners();
    });
    _initialized = true;
    notifyListeners();
  }

  AppsCompanion _buildAppCompanion(dynamic data) => AppsCompanion(
        packageName: Value(data["packageName"]),
        name: Value(data["name"]),
        version: Value(data["version"] ?? "(unknown)"),
        banner: Value(data["banner"]),
        icon: Value(data["icon"]),
        hidden: Value.absent(),
        sideloaded: Value(data["sideloaded"]),
      );

  Future<void> _initDefaultCategories() => _database.transaction(() async {

        final starApp = (await _database.getAppByPackage("com.starscntv.livestream.iptv"))[0];

        // 所有应用
        await addCategory("所有应用", shouldNotifyListeners: false);
        final tvAppsCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "所有应用");
        await setCategoryType(tvAppsCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in _applications) {
          await addToCategory(app, tvAppsCategory, shouldNotifyListeners: false);
        }

        // 地方台
        final localTv = [];
        localTv.add(starApp);
        await addCategory("地方台",shouldNotifyListeners: false);
        final localTvCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "地方台");
        await setCategoryType(localTvCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in localTv) {
          await addToCategory(app,localTvCategory,shouldNotifyListeners: false);
        }

        // 央视
        final CCTV = [];
        CCTV.add(starApp);
        CCTV.add((await _database.getAppByPackage("https://tv.cctv.com/live/"))[0]);
        await addCategory("央视",shouldNotifyListeners: false);
        final CCTVCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "央视");
        await setCategoryType(CCTVCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in CCTV) {
          await addToCategory(app,CCTVCategory,shouldNotifyListeners: false);
        }

        // 动画
        final anim = [];
        anim.add(starApp);
        anim.add((await _database.getAppByPackage("https://www.bdys10.com/s/donghua?order=1"))[0]);
        await addCategory("动画",shouldNotifyListeners: false);
        final animCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "动画");
        await setCategoryType(animCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in anim) {
          await addToCategory(app,animCategory,shouldNotifyListeners: false);
        }

        // 综艺
        final varietyShow = [];
        varietyShow.add(starApp);
        varietyShow.add((await _database.getAppByPackage("https://www.bdys10.com/s/zongyi?area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"))[0]);
        varietyShow.add((await _database.getAppByPackage("https://www.yingshi.tv/vod/show/by/time/id/3.html"))[0]);
        await addCategory("综艺",shouldNotifyListeners: false);
        final varietyShowCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "综艺");
        await setCategoryType(varietyShowCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in varietyShow) {
          await addToCategory(app,varietyShowCategory,shouldNotifyListeners: false);
        }

        // 记录片
        final documentary = [];
        documentary.add(starApp);
        documentary.add((await _database.getAppByPackage("https://www.bdys10.com/s/jilu?order=1"))[0]);
        documentary.add((await _database.getAppByPackage("https://www.youtube.com/@FreeDocumentaryNature/playlists"))[0]);
        documentary.add((await _database.getAppByPackage("https://www.youtube.com/@BestDoc/playlists"))[0]);
        documentary.add((await _database.getAppByPackage("https://www.youtube.com/@DWDocumentary/playlists"))[0]);
        documentary.add((await _database.getAppByPackage("https://www.youtube.com/@NatGeo/playlists"))[0]);
        documentary.add((await _database.getAppByPackage("https://www.yingshi.tv/vod/show/by/time/id/5.html"))[0]);
        await addCategory("记录片",shouldNotifyListeners: false);
        final documentaryCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "记录片");
        await setCategoryType(documentaryCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in documentary) {
          await addToCategory(app,documentaryCategory,shouldNotifyListeners: false);
        }

        // 电视剧
        final soupOpera = [];
        soupOpera.add(starApp);
        soupOpera.add((await _database.getAppByPackage("https://www.bdys10.com/s/all?type=1&area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"))[0]);
        soupOpera.add((await _database.getAppByPackage("https://www.youtube.com/@user-mr4qg5bw3h/playlists"))[0]);
        soupOpera.add((await _database.getAppByPackage("https://www.youtube.com/@user-rk6sx4vp8u/playlists"))[0]);
        soupOpera.add((await _database.getAppByPackage("https://www.youtube.com/@user-kw5no6eh4p/playlists"))[0]);
        soupOpera.add((await _database.getAppByPackage("https://www.yingshi.tv/vod/show/by/time/id/1.html"))[0]);
        await addCategory("电视剧",shouldNotifyListeners: false);
        final soupOperaCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "电视剧");
        await setCategoryType(soupOperaCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in soupOpera) {
          await addToCategory(app,soupOperaCategory,shouldNotifyListeners: false);
        }

        // 电影
        final film = [];
        film.add(starApp);
        film.add((await _database.getAppByPackage("https://www.bdys10.com/s/all?type=0&area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"))[0]);
        film.add((await _database.getAppByPackage("https://www.yingshi.tv/vod/show/by/time/id/2.html"))[0]);
        await addCategory("电影",shouldNotifyListeners: false);
        final filmCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "电影");
        await setCategoryType(filmCategory,CategoryType.grid,shouldNotifyListeners: false);
        for (final app in film) {
          await addToCategory(app,filmCategory,shouldNotifyListeners: false);
        }

        // v2ray
        final v2ray = _applications.where((element) => element.packageName == 'com.v2ray.ang');
        await addCategory("开机后请先启动一下v2ray",shouldNotifyListeners: false);
        final v2rayCategory = _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "开机后请先启动一下v2ray");
        for (final app in v2ray) {
          await addToCategory(app,v2rayCategory,shouldNotifyListeners: false);
        }
        _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      });

  Future<void> _refreshState({bool shouldNotifyListeners = true}) async {
    await _database.transaction(() async {
      List<AppsCompanion> webApps = [];
      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@FreeDocumentaryNature/playlists"),
        name: Value<String>("FreeDocumentaryNature"),
        version: Value<String>("assets/freeDocumentary-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://tv.cctv.com/live/"),
        name: Value<String>("cctv"),
        version: Value<String>("assets/cctv-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.bdys10.com/s/all?type=0&area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"),
        name: Value<String>("bdys10movie"),
        version: Value<String>("assets/bdys10movie-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.bdys10.com/s/all?type=1&area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"),
        name: Value<String>("bdys10soup"),
        version: Value<String>("assets/bdys10soupopera-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.bdys10.com/s/jilu?order=1"),
        name: Value<String>("bdys10doc"),
        version: Value<String>("assets/bdys10doc-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.bdys10.com/s/donghua?order=1"),
        name: Value<String>("bdys10anim"),
        version: Value<String>("assets/bdys10anim-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.bdys10.com/s/zongyi?area=%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86&order=0"),
        name: Value<String>("bdys10variety"),
        version: Value<String>("assets/bdys10variety-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(false),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@NatGeo/playlists"),
        name: Value<String>("netgeo"),
        version: Value<String>("assets/netgeo-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@DWDocumentary/playlists"),
        name: Value<String>("dwdoc"),
        version: Value<String>("assets/dwdoc-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@BestDoc/playlists"),
        name: Value<String>("bestdoc"),
        version: Value<String>("assets/bestdoc-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@user-mr4qg5bw3h/playlists"),
        name: Value<String>("jingxuan"),
        version: Value<String>("assets/jingxuan-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@user-rk6sx4vp8u/playlists"),
        name: Value<String>("haoju"),
        version: Value<String>("assets/haoju-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.youtube.com/@user-kw5no6eh4p/playlists"),
        name: Value<String>("chuse"),
        version: Value<String>("assets/chuse-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.yingshi.tv/vod/show/by/time/id/1.html"),
        name: Value<String>("yingshisoup"),
        version: Value<String>("assets/yingshisoup-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.yingshi.tv/vod/show/by/time/id/2.html"),
        name: Value<String>("yingshimovie"),
        version: Value<String>("assets/yingshimovie-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.yingshi.tv/vod/show/by/time/id/3.html"),
        name: Value<String>("yingshivariety"),
        version: Value<String>("assets/yingshivariety-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      webApps.add(AppsCompanion(
        packageName: Value<String>("https://www.yingshi.tv/vod/show/by/time/id/5.html"),
        name: Value<String>("yingshidoc"),
        version: Value<String>("assets/yingshidoc-min.jpg"),
        isWeb: Value<bool>(true),
        useVpn: Value<bool>(true),
      ));

      final appsFromSystem = (await _fLauncherChannel.getApplications()).map(_buildAppCompanion).toList();

      for (final app in appsFromSystem) {
        if (app.packageName.value == "com.starscntv.livestream.iptv") {
          int i  = appsFromSystem.indexOf(app);
          appsFromSystem.remove(app);
          appsFromSystem.insert(i, app.copyWith(useVpn: Value<bool>(true)));
        }
      }

      appsFromSystem.addAll(webApps);

      final appsRemovedFromSystem = (await _database.listApplications())
          .where((app) => !appsFromSystem.any((systemApp) => systemApp.packageName.value == app.packageName))
          .map((app) => app.packageName)
          .toList();

      final List<String> uninstalledApplications = [];
      await Future.forEach(appsRemovedFromSystem, (String packageName) async {
        if (!(await _fLauncherChannel.applicationExists(packageName))) {
          uninstalledApplications.add(packageName);
        }
      });

      await _database.persistApps(appsFromSystem);
      await _database.deleteApps(uninstalledApplications);

      _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      _applications = await _database.listApplications();
    });
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> launchApp(App app) => _fLauncherChannel.launchApp(app.packageName,app.useVpn);

  Future<void> openAppInfo(App app) => _fLauncherChannel.openAppInfo(app.packageName);

  Future<void> uninstallApp(App app) => _fLauncherChannel.uninstallApp(app.packageName);

  Future<void> openSettings() => _fLauncherChannel.openSettings();

  Future<bool> isDefaultLauncher() => _fLauncherChannel.isDefaultLauncher();

  Future<void> startAmbientMode() => _fLauncherChannel.startAmbientMode();

  Future<void> addToCategory(App app, Category category, {bool shouldNotifyListeners = true}) async {
    int index = await _database.nextAppCategoryOrder(category.id) ?? 0;
    await _database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: category.id,
        appPackageName: app.packageName,
        order: index,
      )
    ]);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> removeFromCategory(App app, Category category) async {
    await _database.deleteAppCategory(category.id, app.packageName);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> saveOrderInCategory(Category category) async {
    final applications = _categoriesWithApps.firstWhere((element) => element.category.id == category.id).applications;
    final orderedAppCategories = <AppsCategoriesCompanion>[];
    for (int i = 0; i < applications.length; ++i) {
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(category.id),
        appPackageName: Value(applications[i].packageName),
        order: Value(i),
      ));
    }
    await _database.replaceAppsCategories(orderedAppCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  void reorderApplication(Category category, int oldIndex, int newIndex) {
    final applications = _categoriesWithApps.firstWhere((element) => element.category.id == category.id).applications;
    final application = applications.removeAt(oldIndex);
    applications.insert(newIndex, application);
    notifyListeners();
  }

  Future<void> addCategory(String categoryName, {bool shouldNotifyListeners = true}) async {
    final orderedCategories = <CategoriesCompanion>[];
    for (int i = 0; i < _categoriesWithApps.length; ++i) {
      final category = _categoriesWithApps[i].category;
      orderedCategories.add(CategoriesCompanion(id: Value(category.id), order: Value(i + 1)));
    }
    await _database.insertCategory(CategoriesCompanion.insert(name: categoryName, order: 0));
    await _database.updateCategories(orderedCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> renameCategory(Category category, String categoryName) async {
    await _database.updateCategory(category.id, CategoriesCompanion(name: Value(categoryName)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> deleteCategory(Category category) async {
    await _database.deleteCategory(category.id);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> moveCategory(int oldIndex, int newIndex) async {
    final categoryWithApps = _categoriesWithApps.removeAt(oldIndex);
    _categoriesWithApps.insert(newIndex, categoryWithApps);
    final orderedCategories = <CategoriesCompanion>[];
    for (int i = 0; i < _categoriesWithApps.length; ++i) {
      final category = _categoriesWithApps[i].category;
      orderedCategories.add(CategoriesCompanion(id: Value(category.id), order: Value(i)));
    }
    await _database.updateCategories(orderedCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> hideApplication(App application) async {
    await _database.updateApp(application.packageName, AppsCompanion(hidden: Value(true)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    _applications = await _database.listApplications();
    notifyListeners();
  }

  Future<void> unHideApplication(App application) async {
    await _database.updateApp(application.packageName, AppsCompanion(hidden: Value(false)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    _applications = await _database.listApplications();
    notifyListeners();
  }

  Future<void> setCategoryType(Category category, CategoryType type, {bool shouldNotifyListeners = true}) async {
    await _database.updateCategory(category.id, CategoriesCompanion(type: Value(type)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> setCategorySort(Category category, CategorySort sort) async {
    await _database.updateCategory(category.id, CategoriesCompanion(sort: Value(sort)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> setCategoryColumnsCount(Category category, int columnsCount) async {
    await _database.updateCategory(category.id, CategoriesCompanion(columnsCount: Value(columnsCount)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> setCategoryRowHeight(Category category, int rowHeight) async {
    await _database.updateCategory(category.id, CategoriesCompanion(rowHeight: Value(rowHeight)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }
}
