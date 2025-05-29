class User{
  String? id;
  String? title;
  String? firstName;
  String? lastName;
  String? email;
  String? password;
  String? phone;
  String? address;

  User({
    this.id,
    this.title,
    this.firstName,
    this.lastName,
    this.email,
    this.password,
    this.phone,
    this.address,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['user_id'];
    title = json['user_title'];
    firstName = json['user_firstName'];
    lastName = json['user_lastName'];
    email = json['user_email'];
    password = json['user_password'];
    phone = json['user_phone'];
    address = json['user_address'];
  }
  Map<String, dynamic> toJson() {
        return {
          'user_id': id,
          'user_title': title,
          'user_firstName': firstName,
          'user_lastName': lastName,
          'user_email': email,
          'user_password': password,
          'user_phone': phone,
          'user_address': address
        };
      }
}