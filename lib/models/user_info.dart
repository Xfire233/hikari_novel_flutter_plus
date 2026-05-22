import 'package:hive_ce/hive.dart';

part 'user_info.g.dart';

@HiveType(typeId: 0, adapterName: "UserInfoAdapter")
class UserInfo {
  @HiveField(0)
  final String avatar;

  @HiveField(1)
  final String uid;

  @HiveField(2)
  final String username;

  @HiveField(3)
  final String userLevel;

  @HiveField(4)
  final String email;

  @HiveField(5)
  final String registerDate;

  @HiveField(6)
  final String contribution;

  @HiveField(7)
  final String experience;

  @HiveField(8)
  final String point;

  @HiveField(9)
  final String maxBookshelfNum;

  @HiveField(10)
  final String maxRecommendNum;

  UserInfo({
    required this.avatar,
    required this.uid,
    required this.username,
    required this.userLevel,
    required this.email,
    required this.registerDate,
    required this.contribution,
    required this.experience,
    required this.point,
    required this.maxBookshelfNum,
    required this.maxRecommendNum,
  });
}
