import 'package:url_launcher/url_launcher.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';

class Navigation extends StatefulWidget {
  Navigation({
    Key key,
  }) : super(key: key);

  @override
  _NavigationState createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {

  @override
  build(BuildContext context) {
    return Container(
      width: 220,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 140,
              child: DrawerHeader(
                child: Image(
                  image: AssetImage(AppController.logoImagePath())
                ),
                decoration: BoxDecoration(
                ),
              ),
            ),
            ListTile(
              title: Text('Modes',
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/modes', (Route<dynamic> route) => false);
              },
            ),
            ListTile(
              title: Text('My Lists',
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/lists', (Route<dynamic> route) => false);
              },
            ),
            ListTile(
              title: Text('My Shows',
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/shows', (Route<dynamic> route) => false);
              },
            ),
            ListTile(
              title: Text('Props',
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/props', (Route<dynamic> route) => false);
              },
            ),
            ListTile(
              title: Text("BLE Research",
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/neils-research', (Route<dynamic> route) => false);
              },
            ),
            ListTile(
              title: Text('Store',
                style: TextStyle(
                  fontSize: 18,
                )
              ),
              onTap: () {
                launch("https://flowtoys.com/");
              },
            ),
            ListTile(
              title: Text(Authentication.isAuthenticated ? 'Logout' : "Sign in",
                style: TextStyle(
                  fontSize: 18,
                  color: Authentication.isAuthenticated ? Colors.red : AppController.blue,
                )
              ),
              onTap: () {
                Authentication.logout();
              },
            ),
          ],
        ),
      )
    );
  }

}


