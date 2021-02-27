import 'package:email_validator/email_validator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/back_button.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LoginPage(title: 'Login');
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  String _errorMessage = '';
  bool get _submitting => _submittedAt != null && DateTime.now().difference(_submittedAt) < Duration(seconds: 20);
  DateTime _submittedAt;

  final email = TextEditingController();
  final password = TextEditingController();

  Map arguments;
  bool _showCloseButton;

  @override
  Widget build(BuildContext context) {
    arguments ??= (ModalRoute.of(context).settings.arguments as Map); 
    if (arguments != null) _showCloseButton ??= arguments['showCloseButton'];

    print("BUILD LOGIN");
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus)
          currentFocus.unfocus();
      },
      child: Scaffold(
        floatingActionButton: _showCloseButton == true ? null : _SkipButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Image(
                  width: 300,
                  image: AssetImage(AppController.logoImagePath())
                ),
                _TextFields(),
                _Links(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _CloseButton() {
    return CircleBackButton(
    );
    // return GestureDetector(
    //   onTap: () {
    //     AppController.pop(null);
    //   },
    //   child: Container(
    //     margin: EdgeInsets.all(10),
    //     child: Text('SKIP'),
    //   )
    // ); 
  }

  _SkipButton() {
    return GestureDetector(
      onTap: () {
        AppController.closeUntilPath('/modes');
      },
      child: Container(
        margin: EdgeInsets.all(10),
        child: Text('SKIP'),
      )
    ); 
  }

  void _submitForm() {
    if (_formKey.currentState.validate()) {
      setState(() {
        _submittedAt = DateTime.now();
        _errorMessage = "";
      });
      Client.authenticate(email.text, password.text).then((response) {
        _submittedAt = null;
        if (response['success'])
          AppController.closeUntilPath('/modes');
        else setState(() {
          _errorMessage = response['message'];
        });
      });
    }
  }

  @override
  void dispose() {
    password.dispose();
    email.dispose();
    super.dispose();
  }

  Widget _TextFields() {
    return Container(
      width: 300,
      margin: EdgeInsets.only(top: 40.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(_errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppController.red),
            ),
            TextFormField(
              autofillHints: [AutofillHints.username],
              controller: email,
              decoration: InputDecoration(
                labelText: 'Email'
              ),
              validator: (value) {
                if (value.isEmpty) return 'Please enter some text';
                else if (!EmailValidator.validate(value.trim()))
                  return "That doesn't look like an email address";
              },
              onFieldSubmitted: (value) {
                _submitForm();
              },
            ),
            TextFormField(
              obscureText: true,
              controller: password,
              autofillHints: [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              validator: (value) {
                if (value.isEmpty) return 'Please enter some text';
              },
              onFieldSubmitted: (value) {
                _submitForm();
              },
            ),
          ],
        ),
      )
    );
  }

  Widget _Links(context) {
    return Container(
      margin: EdgeInsets.only(top: _submitting ? 10.0 : 20.0),
      child: Column(
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: _submitting ? 20.0 : 40.0),
            child: _submitting ?
              SpinKitCircle(color: AppController.blue) :
              GestureDetector(
                child: Text('Login', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppController.blue,
                  fontSize: 18,
                )),
                onTap: _submitForm,
              ),
          ),
          Container(
            child: GestureDetector(
              child: Text('Sign Up', style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppController.blue,
                fontSize: 18,
              )),
              onTap: () {
                Navigator.pushNamed(context, '/signup');
              }
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  child: Text('Forgot Password?', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppController.blue,
                    fontSize: 18,
                  )),
                  onTap: () {
                    Navigator.pushNamed(context, '/password-reset');
                  }
                ),
              ]
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 30.0),
            child: _showCloseButton == true ? _CloseButton() : null,
          )
        ],
      ),
    );
  }

}
