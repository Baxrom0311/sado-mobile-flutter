import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L? of(BuildContext context) {
    return Localizations.of<L>(context, L);
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In uz, this message translates to:
  /// **'SADO - Nutq Terapiyasi'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In uz, this message translates to:
  /// **'Bolalar nutqini rivojlantiruvchi do\'st'**
  String get appTagline;

  /// No description provided for @login.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get login;

  /// No description provided for @register.
  ///
  /// In uz, this message translates to:
  /// **'Ro\'yxatdan o\'tish'**
  String get register;

  /// No description provided for @email.
  ///
  /// In uz, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In uz, this message translates to:
  /// **'Parol'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get fullName;

  /// No description provided for @loginButton.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In uz, this message translates to:
  /// **'Ro\'yxatdan o\'tish'**
  String get registerButton;

  /// No description provided for @noAccount.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntingiz yo\'qmi? Ro\'yxatdan o\'ting'**
  String get noAccount;

  /// No description provided for @hasAccount.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntingiz bormi? Kirish'**
  String get hasAccount;

  /// No description provided for @loginWelcome.
  ///
  /// In uz, this message translates to:
  /// **'Qaytib kelganingizdan xursandmiz!'**
  String get loginWelcome;

  /// No description provided for @registerWelcome.
  ///
  /// In uz, this message translates to:
  /// **'SADO oilasiga qo\'shiling'**
  String get registerWelcome;

  /// No description provided for @forgotPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni unutdingizmi?'**
  String get forgotPassword;

  /// No description provided for @home.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get home;

  /// No description provided for @children.
  ///
  /// In uz, this message translates to:
  /// **'Bolalar'**
  String get children;

  /// No description provided for @exercises.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlar'**
  String get exercises;

  /// No description provided for @progress.
  ///
  /// In uz, this message translates to:
  /// **'Taraqqiyot'**
  String get progress;

  /// No description provided for @profile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get settings;

  /// No description provided for @addChild.
  ///
  /// In uz, this message translates to:
  /// **'Bola qo\'shish'**
  String get addChild;

  /// No description provided for @childName.
  ///
  /// In uz, this message translates to:
  /// **'Bolaning ismi'**
  String get childName;

  /// No description provided for @birthDate.
  ///
  /// In uz, this message translates to:
  /// **'Tug\'ilgan sana'**
  String get birthDate;

  /// No description provided for @gender.
  ///
  /// In uz, this message translates to:
  /// **'Jinsi'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In uz, this message translates to:
  /// **'O\'g\'il bola'**
  String get male;

  /// No description provided for @female.
  ///
  /// In uz, this message translates to:
  /// **'Qiz bola'**
  String get female;

  /// No description provided for @save.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get edit;

  /// No description provided for @ok.
  ///
  /// In uz, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get close;

  /// No description provided for @continueAction.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get continueAction;

  /// No description provided for @startExercise.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni boshlash'**
  String get startExercise;

  /// No description provided for @startAssessment.
  ///
  /// In uz, this message translates to:
  /// **'Baholashni boshlash'**
  String get startAssessment;

  /// No description provided for @recording.
  ///
  /// In uz, this message translates to:
  /// **'Yozib olinmoqda...'**
  String get recording;

  /// No description provided for @tapToRecord.
  ///
  /// In uz, this message translates to:
  /// **'Yozib olish uchun bosing'**
  String get tapToRecord;

  /// No description provided for @tapToStop.
  ///
  /// In uz, this message translates to:
  /// **'To\'xtatish uchun bosing'**
  String get tapToStop;

  /// No description provided for @playRecording.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvni tinglash'**
  String get playRecording;

  /// No description provided for @pauseRecording.
  ///
  /// In uz, this message translates to:
  /// **'Pauza'**
  String get pauseRecording;

  /// No description provided for @playbackEnded.
  ///
  /// In uz, this message translates to:
  /// **'Yozuv tinglandi'**
  String get playbackEnded;

  /// No description provided for @submitAssessment.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get submitAssessment;

  /// No description provided for @assessmentComplete.
  ///
  /// In uz, this message translates to:
  /// **'Baholash tugadi!'**
  String get assessmentComplete;

  /// No description provided for @score.
  ///
  /// In uz, this message translates to:
  /// **'Ball'**
  String get score;

  /// No description provided for @riskLow.
  ///
  /// In uz, this message translates to:
  /// **'Xavf past'**
  String get riskLow;

  /// No description provided for @riskMedium.
  ///
  /// In uz, this message translates to:
  /// **'Xavf o\'rtacha'**
  String get riskMedium;

  /// No description provided for @riskHigh.
  ///
  /// In uz, this message translates to:
  /// **'Xavf yuqori'**
  String get riskHigh;

  /// No description provided for @riskUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Xavf aniqlanmadi'**
  String get riskUnknown;

  /// No description provided for @recommendations.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiyalar'**
  String get recommendations;

  /// No description provided for @recordAgain.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yozish'**
  String get recordAgain;

  /// No description provided for @preparingAssessment.
  ///
  /// In uz, this message translates to:
  /// **'Baholash tayyorlanmoqda...'**
  String get preparingAssessment;

  /// No description provided for @preparingResults.
  ///
  /// In uz, this message translates to:
  /// **'Natijalar tayyorlanmoqda...'**
  String get preparingResults;

  /// No description provided for @microphonePermission.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofonga ruxsat kerak'**
  String get microphonePermission;

  /// No description provided for @microphonePermissionBody.
  ///
  /// In uz, this message translates to:
  /// **'Nutqingizni yozib olish uchun mikrofon ruxsatini bering'**
  String get microphonePermissionBody;

  /// No description provided for @grantPermission.
  ///
  /// In uz, this message translates to:
  /// **'Ruxsat berish'**
  String get grantPermission;

  /// No description provided for @noChildren.
  ///
  /// In uz, this message translates to:
  /// **'Hali bola qo\'shilmagan'**
  String get noChildren;

  /// No description provided for @noChildrenBody.
  ///
  /// In uz, this message translates to:
  /// **'Boshlash uchun birinchi bolangizni qo\'shing'**
  String get noChildrenBody;

  /// No description provided for @noExercises.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlar topilmadi'**
  String get noExercises;

  /// No description provided for @noExercisesBody.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada yangi mashqlar qo\'shiladi'**
  String get noExercisesBody;

  /// No description provided for @noAssessments.
  ///
  /// In uz, this message translates to:
  /// **'Baholashlar topilmadi'**
  String get noAssessments;

  /// No description provided for @noAssessmentsBody.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqingizni bajaring'**
  String get noAssessmentsBody;

  /// No description provided for @noBadges.
  ///
  /// In uz, this message translates to:
  /// **'Hali nishonlar yo\'q'**
  String get noBadges;

  /// No description provided for @loading.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In uz, this message translates to:
  /// **'Xatolik yuz berdi'**
  String get error;

  /// No description provided for @errorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Nimadir noto\'g\'ri ketdi'**
  String get errorTitle;

  /// No description provided for @retry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get retry;

  /// No description provided for @offline.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo\'q'**
  String get offline;

  /// No description provided for @offlineCached.
  ///
  /// In uz, this message translates to:
  /// **'Oflayn rejim — keshlangan ma\'lumot'**
  String get offlineCached;

  /// No description provided for @tryAgainLater.
  ///
  /// In uz, this message translates to:
  /// **'Keyinroq urinib ko\'ring'**
  String get tryAgainLater;

  /// No description provided for @language.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notifications;

  /// No description provided for @settingsAccountSection.
  ///
  /// In uz, this message translates to:
  /// **'Akkaunt'**
  String get settingsAccountSection;

  /// No description provided for @signedInAs.
  ///
  /// In uz, this message translates to:
  /// **'Kirilgan akkaunt'**
  String get signedInAs;

  /// No description provided for @logout.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In uz, this message translates to:
  /// **'Chiqishni xohlaysizmi?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntingizdan chiqasiz'**
  String get logoutConfirmBody;

  /// No description provided for @about.
  ///
  /// In uz, this message translates to:
  /// **'Ilova haqida'**
  String get about;

  /// No description provided for @version.
  ///
  /// In uz, this message translates to:
  /// **'Versiya'**
  String get version;

  /// No description provided for @termsAndPrivacy.
  ///
  /// In uz, this message translates to:
  /// **'Shartlar va maxfiylik'**
  String get termsAndPrivacy;

  /// No description provided for @support.
  ///
  /// In uz, this message translates to:
  /// **'Yordam'**
  String get support;

  /// No description provided for @rateApp.
  ///
  /// In uz, this message translates to:
  /// **'Ilovani baholash'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In uz, this message translates to:
  /// **'Ulashish'**
  String get shareApp;

  /// No description provided for @welcome.
  ///
  /// In uz, this message translates to:
  /// **'Salom'**
  String get welcome;

  /// No description provided for @todayExercises.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi mashqlar'**
  String get todayExercises;

  /// No description provided for @weeklyProgress.
  ///
  /// In uz, this message translates to:
  /// **'Haftalik taraqqiyot'**
  String get weeklyProgress;

  /// No description provided for @totalAssessments.
  ///
  /// In uz, this message translates to:
  /// **'Jami baholashlar'**
  String get totalAssessments;

  /// No description provided for @category.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya'**
  String get category;

  /// No description provided for @difficulty.
  ///
  /// In uz, this message translates to:
  /// **'Qiyinlik darajasi'**
  String get difficulty;

  /// No description provided for @easy.
  ///
  /// In uz, this message translates to:
  /// **'Oson'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get medium;

  /// No description provided for @hard.
  ///
  /// In uz, this message translates to:
  /// **'Qiyin'**
  String get hard;

  /// No description provided for @ageGroup.
  ///
  /// In uz, this message translates to:
  /// **'Yosh guruhi'**
  String get ageGroup;

  /// No description provided for @duration.
  ///
  /// In uz, this message translates to:
  /// **'Davomiyligi'**
  String get duration;

  /// No description provided for @minutes.
  ///
  /// In uz, this message translates to:
  /// **'daqiqa'**
  String get minutes;

  /// No description provided for @onboarding1Title.
  ///
  /// In uz, this message translates to:
  /// **'SADO ga xush kelibsiz!'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Body.
  ///
  /// In uz, this message translates to:
  /// **'Bolangiz nutqini quvonchli va o\'yinli usulda rivojlantiring'**
  String get onboarding1Body;

  /// No description provided for @onboarding2Title.
  ///
  /// In uz, this message translates to:
  /// **'O\'yinli mashqlar'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Body.
  ///
  /// In uz, this message translates to:
  /// **'Qiziqarli vazifalar va to\'tiqush do\'st bilan birga'**
  String get onboarding2Body;

  /// No description provided for @onboarding3Title.
  ///
  /// In uz, this message translates to:
  /// **'Taraqqiyotni kuzating'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Body.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik o\'sish, nishonlar va XP — har kuni yangi marra'**
  String get onboarding3Body;

  /// No description provided for @next.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In uz, this message translates to:
  /// **'O\'tkazib yuborish'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In uz, this message translates to:
  /// **'Boshlash'**
  String get getStarted;

  /// No description provided for @total.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get total;

  /// No description provided for @completed.
  ///
  /// In uz, this message translates to:
  /// **'Bajarilgan'**
  String get completed;

  /// No description provided for @average.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get average;

  /// No description provided for @exerciseNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Mashq topilmadi'**
  String get exerciseNotFound;

  /// No description provided for @uzbekLanguage.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbek tili'**
  String get uzbekLanguage;

  /// No description provided for @russianLanguage.
  ///
  /// In uz, this message translates to:
  /// **'Русский язык'**
  String get russianLanguage;

  /// No description provided for @uzbek.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbek'**
  String get uzbek;

  /// No description provided for @russian.
  ///
  /// In uz, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @emailInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Email noto\'g\'ri'**
  String get emailInvalid;

  /// No description provided for @passwordMinLength.
  ///
  /// In uz, this message translates to:
  /// **'Kamida 6 belgi'**
  String get passwordMinLength;

  /// No description provided for @nameRequired.
  ///
  /// In uz, this message translates to:
  /// **'Ism kiriting'**
  String get nameRequired;

  /// No description provided for @yearsOld.
  ///
  /// In uz, this message translates to:
  /// **'yosh'**
  String get yearsOld;

  /// No description provided for @status.
  ///
  /// In uz, this message translates to:
  /// **'Holat'**
  String get status;

  /// No description provided for @level.
  ///
  /// In uz, this message translates to:
  /// **'Daraja'**
  String get level;

  /// No description provided for @levelBeginner.
  ///
  /// In uz, this message translates to:
  /// **'Yangi boshlovchi'**
  String get levelBeginner;

  /// No description provided for @levelExplorer.
  ///
  /// In uz, this message translates to:
  /// **'Tadqiqotchi'**
  String get levelExplorer;

  /// No description provided for @levelChampion.
  ///
  /// In uz, this message translates to:
  /// **'Chempion'**
  String get levelChampion;

  /// No description provided for @levelMaster.
  ///
  /// In uz, this message translates to:
  /// **'Usta'**
  String get levelMaster;

  /// No description provided for @xp.
  ///
  /// In uz, this message translates to:
  /// **'Tajriba'**
  String get xp;

  /// No description provided for @streak.
  ///
  /// In uz, this message translates to:
  /// **'Ketma-ketlik'**
  String get streak;

  /// No description provided for @streakDays.
  ///
  /// In uz, this message translates to:
  /// **'kun'**
  String get streakDays;

  /// No description provided for @badges.
  ///
  /// In uz, this message translates to:
  /// **'Nishonlar'**
  String get badges;

  /// No description provided for @achievements.
  ///
  /// In uz, this message translates to:
  /// **'Yutuqlar'**
  String get achievements;

  /// No description provided for @leaderboard.
  ///
  /// In uz, this message translates to:
  /// **'Reyting'**
  String get leaderboard;

  /// No description provided for @rewards.
  ///
  /// In uz, this message translates to:
  /// **'Mukofotlar'**
  String get rewards;

  /// No description provided for @badgeFirstStepTitle.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi qadam'**
  String get badgeFirstStepTitle;

  /// No description provided for @badgeFirstStepBody.
  ///
  /// In uz, this message translates to:
  /// **'SADO bilan tanishishni boshladingiz!'**
  String get badgeFirstStepBody;

  /// No description provided for @badgeStreak5Title.
  ///
  /// In uz, this message translates to:
  /// **'Olov yondi!'**
  String get badgeStreak5Title;

  /// No description provided for @badgeStreak5Body.
  ///
  /// In uz, this message translates to:
  /// **'5 kun ketma-ket faol bo\'ldingiz'**
  String get badgeStreak5Body;

  /// No description provided for @badgeAssess10Title.
  ///
  /// In uz, this message translates to:
  /// **'Mashqchi'**
  String get badgeAssess10Title;

  /// No description provided for @badgeAssess10Body.
  ///
  /// In uz, this message translates to:
  /// **'10 ta baholashni yakunladingiz'**
  String get badgeAssess10Body;

  /// No description provided for @badgeLevel5Title.
  ///
  /// In uz, this message translates to:
  /// **'5-daraja'**
  String get badgeLevel5Title;

  /// No description provided for @badgeLevel5Body.
  ///
  /// In uz, this message translates to:
  /// **'Tadqiqotchi darajasiga yetdingiz'**
  String get badgeLevel5Body;

  /// No description provided for @badgeLevel10Title.
  ///
  /// In uz, this message translates to:
  /// **'10-daraja'**
  String get badgeLevel10Title;

  /// No description provided for @badgeLevel10Body.
  ///
  /// In uz, this message translates to:
  /// **'Usta darajasiga ko\'tarildingiz'**
  String get badgeLevel10Body;

  /// No description provided for @badgePerfectTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mukammal!'**
  String get badgePerfectTitle;

  /// No description provided for @badgePerfectBody.
  ///
  /// In uz, this message translates to:
  /// **'95% dan yuqori natija'**
  String get badgePerfectBody;

  /// No description provided for @earnedXp.
  ///
  /// In uz, this message translates to:
  /// **'{xp} XP qozondingiz!'**
  String earnedXp(int xp);

  /// No description provided for @newBadgeUnlocked.
  ///
  /// In uz, this message translates to:
  /// **'Yangi nishon ochildi!'**
  String get newBadgeUnlocked;

  /// No description provided for @mascotGreetingMorning.
  ///
  /// In uz, this message translates to:
  /// **'Xayrli tong! Bugun nima qilamiz?'**
  String get mascotGreetingMorning;

  /// No description provided for @mascotGreetingDay.
  ///
  /// In uz, this message translates to:
  /// **'Salom! Mashq qilishga tayyormisiz?'**
  String get mascotGreetingDay;

  /// No description provided for @mascotGreetingEvening.
  ///
  /// In uz, this message translates to:
  /// **'Xayrli kech! Yana bir martagina mashq?'**
  String get mascotGreetingEvening;

  /// No description provided for @mascotEmptyChildren.
  ///
  /// In uz, this message translates to:
  /// **'Avval bola qo\'shaylik, keyin o\'ynaymiz!'**
  String get mascotEmptyChildren;

  /// No description provided for @mascotEncourage.
  ///
  /// In uz, this message translates to:
  /// **'Davom et, sen ajoyib qilyapsan!'**
  String get mascotEncourage;

  /// No description provided for @mascotAssessmentReady.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofon tayyor! Aniq va sekin gapir.'**
  String get mascotAssessmentReady;

  /// No description provided for @mascotAssessmentDone.
  ///
  /// In uz, this message translates to:
  /// **'Zo\'r! Hozir natijani ko\'rsataman.'**
  String get mascotAssessmentDone;

  /// No description provided for @mascotResultsGreat.
  ///
  /// In uz, this message translates to:
  /// **'Ajoyib natija! Davom etamiz.'**
  String get mascotResultsGreat;

  /// No description provided for @mascotResultsOk.
  ///
  /// In uz, this message translates to:
  /// **'Yaxshi! Kichik mashqlar bilan yanada yaxshi bo\'ladi.'**
  String get mascotResultsOk;

  /// No description provided for @mascotResultsNeedsWork.
  ///
  /// In uz, this message translates to:
  /// **'Hechqisi yo\'q, biz birga o\'rganamiz.'**
  String get mascotResultsNeedsWork;

  /// No description provided for @categoryArticulation.
  ///
  /// In uz, this message translates to:
  /// **'Talaffuz'**
  String get categoryArticulation;

  /// No description provided for @categoryBreathing.
  ///
  /// In uz, this message translates to:
  /// **'Nafas olish'**
  String get categoryBreathing;

  /// No description provided for @categoryVocabulary.
  ///
  /// In uz, this message translates to:
  /// **'Lug\'at'**
  String get categoryVocabulary;

  /// No description provided for @categoryFluency.
  ///
  /// In uz, this message translates to:
  /// **'Ravonlik'**
  String get categoryFluency;

  /// No description provided for @categoryListening.
  ///
  /// In uz, this message translates to:
  /// **'Eshitish'**
  String get categoryListening;

  /// No description provided for @categoryPhonemicAwareness.
  ///
  /// In uz, this message translates to:
  /// **'Tovush sezgirligi'**
  String get categoryPhonemicAwareness;

  /// No description provided for @ageGroup2to3.
  ///
  /// In uz, this message translates to:
  /// **'2-3 yosh'**
  String get ageGroup2to3;

  /// No description provided for @ageGroup3to4.
  ///
  /// In uz, this message translates to:
  /// **'3-4 yosh'**
  String get ageGroup3to4;

  /// No description provided for @ageGroup4to5.
  ///
  /// In uz, this message translates to:
  /// **'4-5 yosh'**
  String get ageGroup4to5;

  /// No description provided for @ageGroup5to6.
  ///
  /// In uz, this message translates to:
  /// **'5-6 yosh'**
  String get ageGroup5to6;

  /// No description provided for @ageGroup6to7.
  ///
  /// In uz, this message translates to:
  /// **'6-7 yosh'**
  String get ageGroup6to7;

  /// No description provided for @allAges.
  ///
  /// In uz, this message translates to:
  /// **'Barcha yoshlar'**
  String get allAges;

  /// No description provided for @filterByAge.
  ///
  /// In uz, this message translates to:
  /// **'Yosh bo\'yicha'**
  String get filterByAge;

  /// No description provided for @filterByDifficulty.
  ///
  /// In uz, this message translates to:
  /// **'Daraja bo\'yicha'**
  String get filterByDifficulty;

  /// No description provided for @allDifficulties.
  ///
  /// In uz, this message translates to:
  /// **'Barcha darajalar'**
  String get allDifficulties;

  /// No description provided for @searchExercisesHint.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni qidirish'**
  String get searchExercisesHint;

  /// No description provided for @clearSearch.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get clearSearch;

  /// No description provided for @noSearchResults.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get noSearchResults;

  /// No description provided for @noSearchResultsBody.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa kalit so\'z bilan urinib ko\'ring'**
  String get noSearchResultsBody;

  /// No description provided for @allChildren.
  ///
  /// In uz, this message translates to:
  /// **'Hammasi'**
  String get allChildren;

  /// No description provided for @filterByChild.
  ///
  /// In uz, this message translates to:
  /// **'Bola bo\'yicha'**
  String get filterByChild;

  /// No description provided for @tabHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get tabHome;

  /// No description provided for @tabExercises.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlar'**
  String get tabExercises;

  /// No description provided for @tabProgress.
  ///
  /// In uz, this message translates to:
  /// **'Taraqqiyot'**
  String get tabProgress;

  /// No description provided for @tabProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @exerciseInstructions.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'riqnoma'**
  String get exerciseInstructions;

  /// No description provided for @targetSounds.
  ///
  /// In uz, this message translates to:
  /// **'Tovushlar'**
  String get targetSounds;

  /// No description provided for @selectChild.
  ///
  /// In uz, this message translates to:
  /// **'Bolani tanlang'**
  String get selectChild;

  /// No description provided for @noChildSelectFirst.
  ///
  /// In uz, this message translates to:
  /// **'Avval bola qo\'shing'**
  String get noChildSelectFirst;

  /// No description provided for @weekMon.
  ///
  /// In uz, this message translates to:
  /// **'Du'**
  String get weekMon;

  /// No description provided for @weekTue.
  ///
  /// In uz, this message translates to:
  /// **'Se'**
  String get weekTue;

  /// No description provided for @weekWed.
  ///
  /// In uz, this message translates to:
  /// **'Ch'**
  String get weekWed;

  /// No description provided for @weekThu.
  ///
  /// In uz, this message translates to:
  /// **'Pa'**
  String get weekThu;

  /// No description provided for @weekFri.
  ///
  /// In uz, this message translates to:
  /// **'Ju'**
  String get weekFri;

  /// No description provided for @weekSat.
  ///
  /// In uz, this message translates to:
  /// **'Sh'**
  String get weekSat;

  /// No description provided for @weekSun.
  ///
  /// In uz, this message translates to:
  /// **'Ya'**
  String get weekSun;

  /// No description provided for @fieldRequired.
  ///
  /// In uz, this message translates to:
  /// **'Bu maydon to\'ldirilishi shart'**
  String get fieldRequired;

  /// No description provided for @loginFailed.
  ///
  /// In uz, this message translates to:
  /// **'Email yoki parol noto\'g\'ri'**
  String get loginFailed;

  /// No description provided for @networkError.
  ///
  /// In uz, this message translates to:
  /// **'Tarmoq xatosi. Internetni tekshiring'**
  String get networkError;

  /// No description provided for @uploadingAudio.
  ///
  /// In uz, this message translates to:
  /// **'Yozuv yuborilmoqda...'**
  String get uploadingAudio;

  /// No description provided for @uploadQueued.
  ///
  /// In uz, this message translates to:
  /// **'Internet yo\'q. Yozuv keyin avtomatik yuboriladi'**
  String get uploadQueued;

  /// No description provided for @uploadsPending.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 yozuv navbatda} other{{count} yozuv navbatda}}'**
  String uploadsPending(int count);

  /// No description provided for @uploadsRetryNow.
  ///
  /// In uz, this message translates to:
  /// **'Hozir yuborish'**
  String get uploadsRetryNow;

  /// No description provided for @uploadsAllSent.
  ///
  /// In uz, this message translates to:
  /// **'Barcha yozuvlar yuborildi'**
  String get uploadsAllSent;

  /// No description provided for @uploadsFailedSome.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 yozuv yuborilmadi} other{{count} yozuv yuborilmadi}}'**
  String uploadsFailedSome(int count);

  /// No description provided for @uploadsSyncedAuto.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 yozuv avtomatik yuborildi} other{{count} yozuv avtomatik yuborildi}}'**
  String uploadsSyncedAuto(int count);

  /// No description provided for @sessionExpired.
  ///
  /// In uz, this message translates to:
  /// **'Sessiya tugadi. Iltimos, qayta kiring'**
  String get sessionExpired;

  /// No description provided for @secondsShort.
  ///
  /// In uz, this message translates to:
  /// **'{count} s'**
  String secondsShort(int count);

  /// No description provided for @secondsLeft.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 soniya qoldi} other{{count} soniya qoldi}}'**
  String secondsLeft(int count);

  /// No description provided for @recordingTimeAlmostUp.
  ///
  /// In uz, this message translates to:
  /// **'Vaqt tugayapti — yakunlang!'**
  String get recordingTimeAlmostUp;

  /// No description provided for @splashTagline.
  ///
  /// In uz, this message translates to:
  /// **'Bolalar uchun aqlli nutq do\'sti'**
  String get splashTagline;

  /// No description provided for @childDetail.
  ///
  /// In uz, this message translates to:
  /// **'Bola haqida'**
  String get childDetail;

  /// No description provided for @editChild.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get editChild;

  /// No description provided for @editChildTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bolani tahrirlash'**
  String get editChildTitle;

  /// No description provided for @deleteChild.
  ///
  /// In uz, this message translates to:
  /// **'Bolani o\'chirish'**
  String get deleteChild;

  /// No description provided for @deleteChildConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Rostdan ham {name} ma\'lumotlarini o\'chirmoqchimisiz?'**
  String deleteChildConfirm(String name);

  /// No description provided for @childUpdated.
  ///
  /// In uz, this message translates to:
  /// **'Bola ma\'lumotlari saqlandi'**
  String get childUpdated;

  /// No description provided for @childDeleted.
  ///
  /// In uz, this message translates to:
  /// **'Bola ma\'lumotlari o\'chirildi'**
  String get childDeleted;

  /// No description provided for @recentAssessments.
  ///
  /// In uz, this message translates to:
  /// **'So\'nggi baholashlar'**
  String get recentAssessments;

  /// No description provided for @averageScore.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha ball'**
  String get averageScore;

  /// No description provided for @noNotifications.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha bildirishnoma yo\'q'**
  String get noNotifications;

  /// No description provided for @noNotificationsBody.
  ///
  /// In uz, this message translates to:
  /// **'Yangiliklar paydo bo\'lganda shu yerda ko\'rasiz'**
  String get noNotificationsBody;

  /// No description provided for @markAllRead.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini o\'qilgan deb belgilash'**
  String get markAllRead;

  /// No description provided for @getReady.
  ///
  /// In uz, this message translates to:
  /// **'Tayyorlaning!'**
  String get getReady;

  /// No description provided for @introTip1.
  ///
  /// In uz, this message translates to:
  /// **'Tinch joyda yozing'**
  String get introTip1;

  /// No description provided for @introTip2.
  ///
  /// In uz, this message translates to:
  /// **'Aniq va sekin gapiring'**
  String get introTip2;

  /// No description provided for @introTip3.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofon yaqin bo\'lsin'**
  String get introTip3;

  /// No description provided for @letsStart.
  ///
  /// In uz, this message translates to:
  /// **'Boshladik!'**
  String get letsStart;

  /// No description provided for @tapToContinue.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish uchun bosing'**
  String get tapToContinue;

  /// No description provided for @yourStats.
  ///
  /// In uz, this message translates to:
  /// **'Sizning statistikangiz'**
  String get yourStats;

  /// No description provided for @accountStats.
  ///
  /// In uz, this message translates to:
  /// **'Akkaunt statistikasi'**
  String get accountStats;

  /// No description provided for @longestStreak.
  ///
  /// In uz, this message translates to:
  /// **'Eng uzun ketma-ketlik'**
  String get longestStreak;

  /// No description provided for @memberSince.
  ///
  /// In uz, this message translates to:
  /// **'Ro\'yxatdan o\'tgan'**
  String get memberSince;

  /// Compact day count, used inside small stat tiles.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{0 kun} =1{1 kun} other{{count} kun}}'**
  String daysShort(int count);

  /// No description provided for @description.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif'**
  String get description;

  /// No description provided for @loadingExercise.
  ///
  /// In uz, this message translates to:
  /// **'Mashq tayyorlanmoqda...'**
  String get loadingExercise;

  /// No description provided for @loadingChild.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'lumot yuklanmoqda...'**
  String get loadingChild;

  /// No description provided for @loadingResults.
  ///
  /// In uz, this message translates to:
  /// **'Natija olinmoqda...'**
  String get loadingResults;

  /// No description provided for @loadingAssessments.
  ///
  /// In uz, this message translates to:
  /// **'Baholashlar yuklanmoqda...'**
  String get loadingAssessments;

  /// No description provided for @loadingFriendly.
  ///
  /// In uz, this message translates to:
  /// **'Bir lahza, tayyorlayapman...'**
  String get loadingFriendly;

  /// No description provided for @listenExample.
  ///
  /// In uz, this message translates to:
  /// **'Namunani tinglash'**
  String get listenExample;

  /// No description provided for @audioUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Audio ochilmadi'**
  String get audioUnavailable;

  /// No description provided for @audioExampleUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Namuna audio mavjud emas'**
  String get audioExampleUnavailable;

  /// No description provided for @chooseChildSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bolani tanlang'**
  String get chooseChildSheetTitle;

  /// No description provided for @chooseChildSheetBody.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni qaysi bola uchun boshlaymiz?'**
  String get chooseChildSheetBody;

  /// No description provided for @addChildShort.
  ///
  /// In uz, this message translates to:
  /// **'Yangi bola qo\'shish'**
  String get addChildShort;

  /// No description provided for @permissionPermanentlyDeniedBody.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofon ruxsati o\'chirilgan. Sozlamalardan yoqing.'**
  String get permissionPermanentlyDeniedBody;

  /// No description provided for @openSettings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalarni ochish'**
  String get openSettings;

  /// No description provided for @microphoneRationaleTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofon nima uchun kerak?'**
  String get microphoneRationaleTitle;

  /// No description provided for @microphoneRationaleBody.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofon faqat siz yozishni boshlaganingizda ishlaydi. Yozuv xavfsiz tarzda saqlanadi va faqat baholash uchun ishlatiladi.'**
  String get microphoneRationaleBody;

  /// No description provided for @notNow.
  ///
  /// In uz, this message translates to:
  /// **'Hozir emas'**
  String get notNow;

  /// No description provided for @allow.
  ///
  /// In uz, this message translates to:
  /// **'Ruxsat berish'**
  String get allow;

  /// No description provided for @periodWeek.
  ///
  /// In uz, this message translates to:
  /// **'Hafta'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In uz, this message translates to:
  /// **'Oy'**
  String get periodMonth;

  /// No description provided for @periodAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get periodAll;

  /// No description provided for @riskDistribution.
  ///
  /// In uz, this message translates to:
  /// **'Xavf taqsimoti'**
  String get riskDistribution;

  /// No description provided for @streakHeatmap.
  ///
  /// In uz, this message translates to:
  /// **'Faollik kalendari'**
  String get streakHeatmap;

  /// No description provided for @categoryBreakdown.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriyalar bo\'yicha'**
  String get categoryBreakdown;

  /// No description provided for @noRiskData.
  ///
  /// In uz, this message translates to:
  /// **'Xavf ma\'lumoti yo\'q'**
  String get noRiskData;

  /// No description provided for @quickActions.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor amallar'**
  String get quickActions;

  /// No description provided for @quickStartExercise.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni boshlash'**
  String get quickStartExercise;

  /// No description provided for @quickStartExerciseHint.
  ///
  /// In uz, this message translates to:
  /// **'Bugun nimadan boshlaymiz?'**
  String get quickStartExerciseHint;

  /// No description provided for @quickAddChild.
  ///
  /// In uz, this message translates to:
  /// **'Bola qo\'shish'**
  String get quickAddChild;

  /// No description provided for @quickAddChildHint.
  ///
  /// In uz, this message translates to:
  /// **'Bolangizni ro\'yxatga qo\'shing'**
  String get quickAddChildHint;

  /// No description provided for @quickAssessment.
  ///
  /// In uz, this message translates to:
  /// **'Bolani tekshirish'**
  String get quickAssessment;

  /// No description provided for @quickAssessmentHint.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor baholash'**
  String get quickAssessmentHint;

  /// No description provided for @motivation1.
  ///
  /// In uz, this message translates to:
  /// **'Har bir mashq — bir qadam oldinga.'**
  String get motivation1;

  /// No description provided for @motivation2.
  ///
  /// In uz, this message translates to:
  /// **'Sen ajoyibsan! Davom et!'**
  String get motivation2;

  /// No description provided for @motivation3.
  ///
  /// In uz, this message translates to:
  /// **'Kichik harakatlar — katta natijalar.'**
  String get motivation3;

  /// No description provided for @motivation4.
  ///
  /// In uz, this message translates to:
  /// **'Bugun ham yangi narsa o\'rganamiz.'**
  String get motivation4;

  /// No description provided for @motivation5.
  ///
  /// In uz, this message translates to:
  /// **'Sabr va mehnat — muvaffaqiyat kaliti.'**
  String get motivation5;

  /// No description provided for @viewAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasini ko\'rish'**
  String get viewAll;

  /// No description provided for @noRecentAssessments.
  ///
  /// In uz, this message translates to:
  /// **'Hali baholash yo\'q'**
  String get noRecentAssessments;

  /// No description provided for @noRecentAssessmentsBody.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqni boshlang!'**
  String get noRecentAssessmentsBody;

  /// No description provided for @editProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get editProfile;

  /// No description provided for @editProfileTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profil ma\'lumotlari'**
  String get editProfileTitle;

  /// No description provided for @editProfileSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz va til afzalligini yangilang'**
  String get editProfileSubtitle;

  /// No description provided for @fullNameField.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get fullNameField;

  /// No description provided for @nameMinLength.
  ///
  /// In uz, this message translates to:
  /// **'Ism kamida 2 ta harfdan iborat bo\'lsin'**
  String get nameMinLength;

  /// No description provided for @languagePreference.
  ///
  /// In uz, this message translates to:
  /// **'Ilova tili'**
  String get languagePreference;

  /// No description provided for @saveChanges.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgarishlarni saqlash'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In uz, this message translates to:
  /// **'Profil yangilandi'**
  String get profileUpdated;

  /// No description provided for @profileSaveError.
  ///
  /// In uz, this message translates to:
  /// **'Saqlashda xatolik. Qaytadan urinib ko\'ring'**
  String get profileSaveError;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanmagan o\'zgarishlar'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlarni saqlamasdan chiqmoqchimisiz?'**
  String get unsavedChangesBody;

  /// No description provided for @discard.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get discard;

  /// No description provided for @stay.
  ///
  /// In uz, this message translates to:
  /// **'Qolish'**
  String get stay;

  /// No description provided for @registerRoleQuestion.
  ///
  /// In uz, this message translates to:
  /// **'Siz kimsiz?'**
  String get registerRoleQuestion;

  /// No description provided for @roleParent.
  ///
  /// In uz, this message translates to:
  /// **'Ota-ona'**
  String get roleParent;

  /// No description provided for @roleParentHint.
  ///
  /// In uz, this message translates to:
  /// **'Bolaning nutqini uyda kuzataman'**
  String get roleParentHint;

  /// No description provided for @roleTeacher.
  ///
  /// In uz, this message translates to:
  /// **'Tarbiyachi'**
  String get roleTeacher;

  /// No description provided for @roleTeacherHint.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha yoki maktabda ishlayman'**
  String get roleTeacherHint;

  /// No description provided for @termsAccept.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari va maxfiylik siyosatini qabul qilaman'**
  String get termsAccept;

  /// No description provided for @termsRequired.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish uchun shartlarni qabul qiling'**
  String get termsRequired;

  /// No description provided for @nextBadgeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi nishongacha'**
  String get nextBadgeTitle;

  /// No description provided for @nextBadgeStreakProgress.
  ///
  /// In uz, this message translates to:
  /// **'{current}/{target} kun ketma-ket'**
  String nextBadgeStreakProgress(int current, int target);

  /// No description provided for @nextBadgeAssessProgress.
  ///
  /// In uz, this message translates to:
  /// **'{current}/{target} baholash'**
  String nextBadgeAssessProgress(int current, int target);

  /// No description provided for @nextBadgeLevelProgress.
  ///
  /// In uz, this message translates to:
  /// **'{current}/{target} daraja'**
  String nextBadgeLevelProgress(int current, int target);

  /// No description provided for @nextBadgeAllUnlocked.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini topdingiz! Yangi nishonlar tez orada qo\'shiladi.'**
  String get nextBadgeAllUnlocked;

  /// No description provided for @nextBadgeKeepGoing.
  ///
  /// In uz, this message translates to:
  /// **'Davom et — yana bir nishon yaqin!'**
  String get nextBadgeKeepGoing;

  /// No description provided for @badgeStatusLocked.
  ///
  /// In uz, this message translates to:
  /// **'Hali yopiq'**
  String get badgeStatusLocked;

  /// No description provided for @badgeStatusUnlocked.
  ///
  /// In uz, this message translates to:
  /// **'Ochildi!'**
  String get badgeStatusUnlocked;

  /// No description provided for @badgeUnlockedFooter.
  ///
  /// In uz, this message translates to:
  /// **'Tabriklayman! Yana yutuqlarni ochishda davom et.'**
  String get badgeUnlockedFooter;

  /// No description provided for @badgeLockedFooter.
  ///
  /// In uz, this message translates to:
  /// **'Davom et — bu nishon ham seni kutmoqda.'**
  String get badgeLockedFooter;

  /// No description provided for @badgeDetailsHint.
  ///
  /// In uz, this message translates to:
  /// **'Nishon haqida batafsil'**
  String get badgeDetailsHint;

  /// No description provided for @badgeProgressLabel.
  ///
  /// In uz, this message translates to:
  /// **'Joriy holat'**
  String get badgeProgressLabel;

  /// No description provided for @badgeFirstStepHint.
  ///
  /// In uz, this message translates to:
  /// **'SADO ilovasini birinchi marta ochib mashq qilib ko\'r.'**
  String get badgeFirstStepHint;

  /// No description provided for @badgeStreak5Hint.
  ///
  /// In uz, this message translates to:
  /// **'5 kun ketma-ket faol bo\'l — har kuni bittadan mashq yetarli.'**
  String get badgeStreak5Hint;

  /// No description provided for @badgeAssess10Hint.
  ///
  /// In uz, this message translates to:
  /// **'10 ta baholashni yakunla. Har bir mashq seni shu nishonga yaqinlashtiradi.'**
  String get badgeAssess10Hint;

  /// No description provided for @badgeLevel5Hint.
  ///
  /// In uz, this message translates to:
  /// **'5-darajaga yet — har bir mashq XP olib keladi.'**
  String get badgeLevel5Hint;

  /// No description provided for @badgeLevel10Hint.
  ///
  /// In uz, this message translates to:
  /// **'10-darajaga ko\'taril — sabr va mashq bilan!'**
  String get badgeLevel10Hint;

  /// No description provided for @badgePerfectHint.
  ///
  /// In uz, this message translates to:
  /// **'Bitta baholashda 95% va undan yuqori natija ko\'rsat.'**
  String get badgePerfectHint;

  /// No description provided for @tryAnotherExercise.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa mashq'**
  String get tryAnotherExercise;

  /// No description provided for @shareResult.
  ///
  /// In uz, this message translates to:
  /// **'Natijani ulashish'**
  String get shareResult;

  /// No description provided for @resultCopied.
  ///
  /// In uz, this message translates to:
  /// **'Natija nusxalandi'**
  String get resultCopied;

  /// No description provided for @shareResultMessage.
  ///
  /// In uz, this message translates to:
  /// **'🦜 SADO baholash natijasi: {percent}% • {risk}. Sen ajoyib ish qildim!'**
  String shareResultMessage(int percent, String risk);

  /// No description provided for @notificationsToggleTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notificationsToggleTitle;

  /// No description provided for @notificationsOnHint.
  ///
  /// In uz, this message translates to:
  /// **'Yangiliklar va eslatmalar yuborilib turadi'**
  String get notificationsOnHint;

  /// No description provided for @notificationsOffHint.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar o\'chirilgan'**
  String get notificationsOffHint;

  /// No description provided for @audioQualitySection.
  ///
  /// In uz, this message translates to:
  /// **'Audio sifati'**
  String get audioQualitySection;

  /// No description provided for @audioQualityTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yozuv sifati'**
  String get audioQualityTitle;

  /// No description provided for @audioQualitySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Yuqori sifat aniq, lekin trafik ko\'proq'**
  String get audioQualitySubtitle;

  /// No description provided for @audioQualityLow.
  ///
  /// In uz, this message translates to:
  /// **'Past'**
  String get audioQualityLow;

  /// No description provided for @audioQualityLowHint.
  ///
  /// In uz, this message translates to:
  /// **'Tez yuklanadi, kichik fayl'**
  String get audioQualityLowHint;

  /// No description provided for @audioQualityStandard.
  ///
  /// In uz, this message translates to:
  /// **'Standart'**
  String get audioQualityStandard;

  /// No description provided for @audioQualityStandardHint.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etiladi'**
  String get audioQualityStandardHint;

  /// No description provided for @audioQualityHigh.
  ///
  /// In uz, this message translates to:
  /// **'Yuqori'**
  String get audioQualityHigh;

  /// No description provided for @audioQualityHighHint.
  ///
  /// In uz, this message translates to:
  /// **'Aniq, lekin og\'irroq'**
  String get audioQualityHighHint;

  /// No description provided for @lastAssessmentLabel.
  ///
  /// In uz, this message translates to:
  /// **'So\'nggi baholash'**
  String get lastAssessmentLabel;

  /// No description provided for @noAssessmentsYetShort.
  ///
  /// In uz, this message translates to:
  /// **'Hali baholanmagan'**
  String get noAssessmentsYetShort;

  /// No description provided for @dateRelativeToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun'**
  String get dateRelativeToday;

  /// No description provided for @dateRelativeYesterday.
  ///
  /// In uz, this message translates to:
  /// **'Kecha'**
  String get dateRelativeYesterday;

  /// No description provided for @dateRelativeDaysAgo.
  ///
  /// In uz, this message translates to:
  /// **'{days, plural, =1{1 kun oldin} other{{days} kun oldin}}'**
  String dateRelativeDaysAgo(int days);

  /// No description provided for @dateRelativeWeeksAgo.
  ///
  /// In uz, this message translates to:
  /// **'{weeks, plural, =1{1 hafta oldin} other{{weeks} hafta oldin}}'**
  String dateRelativeWeeksAgo(int weeks);

  /// No description provided for @dateRelativeMonthsAgo.
  ///
  /// In uz, this message translates to:
  /// **'{months, plural, =1{1 oy oldin} other{{months} oy oldin}}'**
  String dateRelativeMonthsAgo(int months);

  /// No description provided for @kindergarten.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha'**
  String get kindergarten;

  /// No description provided for @kindergartenOptional.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha (ixtiyoriy)'**
  String get kindergartenOptional;

  /// No description provided for @selectKindergarten.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'chani tanlang'**
  String get selectKindergarten;

  /// No description provided for @kindergartenSheetBody.
  ///
  /// In uz, this message translates to:
  /// **'Bolangiz qatnaydigan bog\'chani toping'**
  String get kindergartenSheetBody;

  /// No description provided for @kindergartensSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha nomi bo\'yicha izlash'**
  String get kindergartensSearchHint;

  /// No description provided for @noKindergartens.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get noKindergartens;

  /// No description provided for @noKindergartensBody.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa kalit so\'z bilan urinib ko\'ring'**
  String get noKindergartensBody;

  /// No description provided for @clearKindergarten.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'chani olib tashlash'**
  String get clearKindergarten;

  /// No description provided for @kindergartenNotSet.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha tanlanmagan'**
  String get kindergartenNotSet;

  /// No description provided for @pendingUploadsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish navbati'**
  String get pendingUploadsTitle;

  /// No description provided for @pendingUploadsSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Internet yo\'q paytda yozilgan ovozlar shu yerda yuborilishini kutadi'**
  String get pendingUploadsSubtitle;

  /// No description provided for @pendingUploadsRetryAll.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini yuborish'**
  String get pendingUploadsRetryAll;

  /// No description provided for @pendingUploadsAllSent.
  ///
  /// In uz, this message translates to:
  /// **'Hammasi yuborildi!'**
  String get pendingUploadsAllSent;

  /// No description provided for @pendingUploadsAllSentBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet uzilganda ham yozuvlaringiz xavfsiz turadi va onlayn bo\'lishi bilan avtomatik yuboriladi.'**
  String get pendingUploadsAllSentBody;

  /// No description provided for @pendingUploadDiscard.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvni o\'chirish'**
  String get pendingUploadDiscard;

  /// No description provided for @pendingUploadDiscardConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Bu yozuvni o\'chirmoqchimisiz? Audio fayl ham qaytarib bo\'lmaydigan tarzda o\'chiriladi.'**
  String get pendingUploadDiscardConfirm;

  /// No description provided for @pendingUploadDiscarded.
  ///
  /// In uz, this message translates to:
  /// **'Yozuv o\'chirildi'**
  String get pendingUploadDiscarded;

  /// No description provided for @pendingUploadRetries.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Hali urinilmadi} =1{1 marta urinildi} other{{count} marta urinildi}}'**
  String pendingUploadRetries(int count);

  /// No description provided for @pendingUploadAddedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yozildi: {when}'**
  String pendingUploadAddedAt(String when);

  /// No description provided for @pendingUploadChildLabel.
  ///
  /// In uz, this message translates to:
  /// **'Bola'**
  String get pendingUploadChildLabel;

  /// No description provided for @pendingUploadExerciseLabel.
  ///
  /// In uz, this message translates to:
  /// **'Mashq'**
  String get pendingUploadExerciseLabel;

  /// No description provided for @pendingUploadUnknownChild.
  ///
  /// In uz, this message translates to:
  /// **'Bola ma\'lumoti yo\'q'**
  String get pendingUploadUnknownChild;

  /// No description provided for @pendingUploadUnknownExercise.
  ///
  /// In uz, this message translates to:
  /// **'Mashq ma\'lumoti yo\'q'**
  String get pendingUploadUnknownExercise;

  /// No description provided for @pendingUploadOfflineHint.
  ///
  /// In uz, this message translates to:
  /// **'Internet yo\'q. Onlayn bo\'lganda avtomatik yuboriladi.'**
  String get pendingUploadOfflineHint;

  /// No description provided for @last7Days.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi 7 kun'**
  String get last7Days;

  /// No description provided for @last7DaysEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu haftada baholash bo\'lmadi'**
  String get last7DaysEmpty;

  /// No description provided for @last7DaysActiveDays.
  ///
  /// In uz, this message translates to:
  /// **'{active}/7 kun faol'**
  String last7DaysActiveDays(int active);

  /// No description provided for @last7DaysAssessments.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Bahosiz} =1{1 ta baholash} other{{count} ta baholash}}'**
  String last7DaysAssessments(int count);

  /// No description provided for @recommendedForChild.
  ///
  /// In uz, this message translates to:
  /// **'{name} uchun tavsiya etiladi'**
  String recommendedForChild(String name);

  /// No description provided for @recommendedAgeSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{age} • {name} uchun'**
  String recommendedAgeSubtitle(String age, String name);

  /// No description provided for @progressLevelTitle.
  ///
  /// In uz, this message translates to:
  /// **'Daraja taraqqiyoti'**
  String get progressLevelTitle;

  /// No description provided for @progressLevelSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Har bir mashq sizni keyingi darajaga yaqinlashtiradi'**
  String get progressLevelSubtitle;

  /// No description provided for @viewAllBadges.
  ///
  /// In uz, this message translates to:
  /// **'Barcha nishonlar'**
  String get viewAllBadges;

  /// No description provided for @yourRecordingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sizning yozuvingiz'**
  String get yourRecordingTitle;

  /// No description provided for @audioCouldNotLoad.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvni yuklab bo\'lmadi'**
  String get audioCouldNotLoad;

  /// No description provided for @aboutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ilova haqida'**
  String get aboutTitle;

  /// No description provided for @aboutAppName.
  ///
  /// In uz, this message translates to:
  /// **'SADO'**
  String get aboutAppName;

  /// No description provided for @aboutAppDescription.
  ///
  /// In uz, this message translates to:
  /// **'SADO — bolalar nutqini rivojlantiruvchi quvnoq do\'st. Mashqlar, baholash va kunlik taraqqiyot — barchasi bir joyda. Ovozli yozuvlar xavfsiz tarzda saqlanadi va faqat baholash uchun ishlatiladi.'**
  String get aboutAppDescription;

  /// No description provided for @aboutBuiltBy.
  ///
  /// In uz, this message translates to:
  /// **'Toshkentda ❤️ bilan yaratildi'**
  String get aboutBuiltBy;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In uz, this message translates to:
  /// **'Versiya'**
  String get aboutVersionLabel;

  /// No description provided for @aboutBuildLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ilish'**
  String get aboutBuildLabel;

  /// No description provided for @aboutTermsHeading.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari'**
  String get aboutTermsHeading;

  /// No description provided for @aboutTermsBody.
  ///
  /// In uz, this message translates to:
  /// **'SADO ilovasidan foydalanib, siz quyidagilarga rozilik bildirasiz: ilova bolalarning nutqini rivojlantirish uchun mo\'ljallangan; baholash natijalari tibbiy tashxis emas, balki ko\'rsatkichdir; barcha ovozli yozuvlar siz tomondan boshlaganda yozib olinadi va bekor qilish mumkin; SADO logoped maslahatining o\'rnini bosmaydi.'**
  String get aboutTermsBody;

  /// No description provided for @aboutPrivacyHeading.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get aboutPrivacyHeading;

  /// No description provided for @aboutPrivacyBody.
  ///
  /// In uz, this message translates to:
  /// **'Biz bolalaringiz haqidagi ma\'lumotni jiddiy himoya qilamiz. Ovozli yozuvlar shifrlangan tarzda uzatiladi va faqat baholash uchun ishlatiladi. Hech qanday reklama beruvchi yoki uchinchi tomonga sotilmaydi. Akkauntingizni o\'chirsangiz, barcha bog\'liq ma\'lumot ham o\'chiriladi.'**
  String get aboutPrivacyBody;

  /// No description provided for @aboutSupportHeading.
  ///
  /// In uz, this message translates to:
  /// **'Yordam'**
  String get aboutSupportHeading;

  /// No description provided for @aboutSupportBody.
  ///
  /// In uz, this message translates to:
  /// **'Savolingiz yoki taklifingiz bormi? Bizga yozing — biz har doim quloqdamiz.'**
  String get aboutSupportBody;

  /// No description provided for @aboutSupportEmail.
  ///
  /// In uz, this message translates to:
  /// **'support@sado.uz'**
  String get aboutSupportEmail;

  /// No description provided for @aboutCopyEmail.
  ///
  /// In uz, this message translates to:
  /// **'Emailni nusxalash'**
  String get aboutCopyEmail;

  /// No description provided for @aboutEmailCopied.
  ///
  /// In uz, this message translates to:
  /// **'Email nusxalandi: {email}'**
  String aboutEmailCopied(String email);

  /// No description provided for @aboutLicensesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ochiq manba litsenziyalari'**
  String get aboutLicensesTitle;

  /// No description provided for @aboutLicensesSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Loyihada ishlatilgan kutubxonalar ro\'yxati'**
  String get aboutLicensesSubtitle;

  /// No description provided for @aboutTermsOpen.
  ///
  /// In uz, this message translates to:
  /// **'Shartlarni o\'qish'**
  String get aboutTermsOpen;

  /// No description provided for @aboutPrivacyOpen.
  ///
  /// In uz, this message translates to:
  /// **'Siyosatni o\'qish'**
  String get aboutPrivacyOpen;

  /// No description provided for @dailyGoalDoneTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi maqsad bajarildi! 🎉'**
  String get dailyGoalDoneTitle;

  /// No description provided for @dailyGoalDoneSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Streakni davom ettirish uchun ertaga ham keling'**
  String get dailyGoalDoneSubtitle;

  /// No description provided for @dailyGoalPendingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi maqsad'**
  String get dailyGoalPendingTitle;

  /// No description provided for @dailyGoalPendingSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugun bitta mashqni bajaring'**
  String get dailyGoalPendingSubtitle;

  /// No description provided for @dailyGoalCta.
  ///
  /// In uz, this message translates to:
  /// **'Boshlash'**
  String get dailyGoalCta;

  /// No description provided for @dailyGoalDoneBadge.
  ///
  /// In uz, this message translates to:
  /// **'Bajarildi'**
  String get dailyGoalDoneBadge;

  /// No description provided for @dailyGoalSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik maqsad — {state}'**
  String dailyGoalSemantics(String state);

  /// No description provided for @phonemeBreakdownTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tovushlar tahlili'**
  String get phonemeBreakdownTitle;

  /// No description provided for @phonemeBreakdownSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Har bir tovush bo\'yicha aniqlik'**
  String get phonemeBreakdownSubtitle;

  /// No description provided for @phonemeAccuracyPercent.
  ///
  /// In uz, this message translates to:
  /// **'{percent}%'**
  String phonemeAccuracyPercent(int percent);

  /// No description provided for @phonemeErrorSubstitution.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get phonemeErrorSubstitution;

  /// No description provided for @phonemeErrorOmission.
  ///
  /// In uz, this message translates to:
  /// **'Tushib qolgan'**
  String get phonemeErrorOmission;

  /// No description provided for @phonemeErrorDistortion.
  ///
  /// In uz, this message translates to:
  /// **'Buzilgan'**
  String get phonemeErrorDistortion;

  /// No description provided for @phonemeErrorOther.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa xato'**
  String get phonemeErrorOther;

  /// No description provided for @fluencyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ravonlik'**
  String get fluencyTitle;

  /// No description provided for @fluencySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Nutq tezligi va pauzalar'**
  String get fluencySubtitle;

  /// No description provided for @fluencyRateLabel.
  ///
  /// In uz, this message translates to:
  /// **'Tezlik'**
  String get fluencyRateLabel;

  /// No description provided for @fluencyRateValue.
  ///
  /// In uz, this message translates to:
  /// **'{value} bo\'g\'in/sek'**
  String fluencyRateValue(String value);

  /// No description provided for @fluencyPauseLabel.
  ///
  /// In uz, this message translates to:
  /// **'Pauzalar'**
  String get fluencyPauseLabel;

  /// No description provided for @fluencyPauseValue.
  ///
  /// In uz, this message translates to:
  /// **'{percent}%'**
  String fluencyPauseValue(int percent);

  /// No description provided for @fluencyRepetitionsLabel.
  ///
  /// In uz, this message translates to:
  /// **'Takrorlar'**
  String get fluencyRepetitionsLabel;

  /// No description provided for @fluencyRepetitionsValue.
  ///
  /// In uz, this message translates to:
  /// **'{count}'**
  String fluencyRepetitionsValue(int count);

  /// No description provided for @voiceQualityTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz sifati'**
  String get voiceQualityTitle;

  /// No description provided for @voiceQualitySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Klinik o\'lchovlar bo\'yicha tahlil'**
  String get voiceQualitySubtitle;

  /// No description provided for @voiceQualityJitterLabel.
  ///
  /// In uz, this message translates to:
  /// **'Jitter'**
  String get voiceQualityJitterLabel;

  /// No description provided for @voiceQualityJitterDescription.
  ///
  /// In uz, this message translates to:
  /// **'Ohang barqarorligi'**
  String get voiceQualityJitterDescription;

  /// No description provided for @voiceQualityShimmerLabel.
  ///
  /// In uz, this message translates to:
  /// **'Shimmer'**
  String get voiceQualityShimmerLabel;

  /// No description provided for @voiceQualityShimmerDescription.
  ///
  /// In uz, this message translates to:
  /// **'Tovush kuchining barqarorligi'**
  String get voiceQualityShimmerDescription;

  /// No description provided for @voiceQualityHnrLabel.
  ///
  /// In uz, this message translates to:
  /// **'HNR'**
  String get voiceQualityHnrLabel;

  /// No description provided for @voiceQualityHnrDescription.
  ///
  /// In uz, this message translates to:
  /// **'Sof tovush nisbati'**
  String get voiceQualityHnrDescription;

  /// No description provided for @voiceQualitySpeechRateLabel.
  ///
  /// In uz, this message translates to:
  /// **'Nutq tezligi'**
  String get voiceQualitySpeechRateLabel;

  /// No description provided for @voiceQualitySpeechRateDescription.
  ///
  /// In uz, this message translates to:
  /// **'Daqiqada so\'zlar soni'**
  String get voiceQualitySpeechRateDescription;

  /// No description provided for @voiceQualityPercentValue.
  ///
  /// In uz, this message translates to:
  /// **'{value}%'**
  String voiceQualityPercentValue(String value);

  /// No description provided for @voiceQualityDecibelValue.
  ///
  /// In uz, this message translates to:
  /// **'{value} dB'**
  String voiceQualityDecibelValue(String value);

  /// No description provided for @voiceQualityWpmValue.
  ///
  /// In uz, this message translates to:
  /// **'{value} so\'z/daq'**
  String voiceQualityWpmValue(String value);

  /// No description provided for @voiceQualityStatusNormal.
  ///
  /// In uz, this message translates to:
  /// **'Me\'yorda'**
  String get voiceQualityStatusNormal;

  /// No description provided for @voiceQualityStatusElevated.
  ///
  /// In uz, this message translates to:
  /// **'Yengil og\'ish'**
  String get voiceQualityStatusElevated;

  /// No description provided for @voiceQualityStatusAbnormal.
  ///
  /// In uz, this message translates to:
  /// **'E\'tibor talab qiladi'**
  String get voiceQualityStatusAbnormal;

  /// No description provided for @voiceQualityStatusUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Aniqlanmadi'**
  String get voiceQualityStatusUnknown;

  /// No description provided for @voiceQualityHeadlineNormal.
  ///
  /// In uz, this message translates to:
  /// **'Bola ovozi sog\'lom diapazonda'**
  String get voiceQualityHeadlineNormal;

  /// No description provided for @voiceQualityHeadlineElevated.
  ///
  /// In uz, this message translates to:
  /// **'Ba\'zi o\'lchovlar me\'yor chetida'**
  String get voiceQualityHeadlineElevated;

  /// No description provided for @voiceQualityHeadlineAbnormal.
  ///
  /// In uz, this message translates to:
  /// **'Logoped bilan maslahatlashish tavsiya etiladi'**
  String get voiceQualityHeadlineAbnormal;

  /// No description provided for @voiceQualitySemantics.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz sifati: {status}'**
  String voiceQualitySemantics(String status);

  /// No description provided for @recommendationsSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Sizga maxsus tayyorlangan'**
  String get recommendationsSubtitle;

  /// No description provided for @recommendationPriorityHigh.
  ///
  /// In uz, this message translates to:
  /// **'Muhim'**
  String get recommendationPriorityHigh;

  /// No description provided for @recommendationPriorityMedium.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get recommendationPriorityMedium;

  /// No description provided for @recommendationPriorityLow.
  ///
  /// In uz, this message translates to:
  /// **'Maslahat'**
  String get recommendationPriorityLow;

  /// No description provided for @analysisUnavailableTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tahlil hozircha mavjud emas'**
  String get analysisUnavailableTitle;

  /// No description provided for @analysisUnavailableBody.
  ///
  /// In uz, this message translates to:
  /// **'Tahlil tayyorlanmoqda. Bir necha daqiqadan so\'ng qayta tekshiring.'**
  String get analysisUnavailableBody;

  /// No description provided for @analysisLoadingMessage.
  ///
  /// In uz, this message translates to:
  /// **'AI tahlilini yuklamoqda…'**
  String get analysisLoadingMessage;

  /// No description provided for @phonemeListSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Tovushlar tahlili — {count} ta tovush'**
  String phonemeListSemantics(int count);

  /// No description provided for @weakPhonemesTitle.
  ///
  /// In uz, this message translates to:
  /// **'E\'tibor talab qiladigan tovushlar'**
  String get weakPhonemesTitle;

  /// No description provided for @weakPhonemesSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'AI shu tovushlar ustida ishlashni tavsiya qiladi'**
  String get weakPhonemesSubtitle;

  /// No description provided for @weakPhonemesEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha alohida e\'tibor talab qiladigan tovushlar topilmadi'**
  String get weakPhonemesEmpty;

  /// No description provided for @weakPhonemesSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Zaif tovushlar — {count} ta'**
  String weakPhonemesSemantics(int count);

  /// No description provided for @transcriptTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bola nima dedi'**
  String get transcriptTitle;

  /// No description provided for @transcriptSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'AI tomonidan tan olingan matn'**
  String get transcriptSubtitle;

  /// No description provided for @transcriptEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Matn aniqlanmadi'**
  String get transcriptEmpty;

  /// No description provided for @synthesizedRecPracticePhoneme.
  ///
  /// In uz, this message translates to:
  /// **'\"{phoneme}\" tovushini har kuni 5 daqiqa mashq qiling'**
  String synthesizedRecPracticePhoneme(String phoneme);

  /// No description provided for @synthesizedRecConsistency.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik mashqlar nutqning aniqligini oshiradi'**
  String get synthesizedRecConsistency;

  /// No description provided for @synthesizedRecCelebrate.
  ///
  /// In uz, this message translates to:
  /// **'Bola yutuqlarini har kuni nishonlang'**
  String get synthesizedRecCelebrate;

  /// No description provided for @assignments.
  ///
  /// In uz, this message translates to:
  /// **'Vazifalar'**
  String get assignments;

  /// No description provided for @assignmentsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Logoped vazifalari'**
  String get assignmentsTitle;

  /// No description provided for @assignmentsSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Logoped tomonidan berilgan mashqlar'**
  String get assignmentsSubtitle;

  /// No description provided for @assignmentsHomeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi vazifalar'**
  String get assignmentsHomeTitle;

  /// No description provided for @assignmentsHomeBody.
  ///
  /// In uz, this message translates to:
  /// **'Logopeddan {count} ta yangi vazifa kutmoqda'**
  String assignmentsHomeBody(int count);

  /// No description provided for @assignmentsHomeBodyOne.
  ///
  /// In uz, this message translates to:
  /// **'Logopeddan 1 ta yangi vazifa kutmoqda'**
  String get assignmentsHomeBodyOne;

  /// No description provided for @assignmentsHomeOpen.
  ///
  /// In uz, this message translates to:
  /// **'Vazifalarni ochish'**
  String get assignmentsHomeOpen;

  /// No description provided for @assignmentsEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha vazifalar yo\'q'**
  String get assignmentsEmptyTitle;

  /// No description provided for @assignmentsEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Logopedingiz yangi mashq qo\'shganida shu yerda paydo bo\'ladi.'**
  String get assignmentsEmptyBody;

  /// No description provided for @assignmentsErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Vazifalarni yuklab bo\'lmadi'**
  String get assignmentsErrorTitle;

  /// No description provided for @assignmentsErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internetni tekshirib, qayta urinib ko\'ring.'**
  String get assignmentsErrorBody;

  /// No description provided for @assignmentsRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinib ko\'rish'**
  String get assignmentsRetry;

  /// No description provided for @assignmentsLoading.
  ///
  /// In uz, this message translates to:
  /// **'Vazifalar yuklanmoqda…'**
  String get assignmentsLoading;

  /// No description provided for @assignmentsPendingHeader.
  ///
  /// In uz, this message translates to:
  /// **'Bajarish kerak'**
  String get assignmentsPendingHeader;

  /// No description provided for @assignmentsCompletedHeader.
  ///
  /// In uz, this message translates to:
  /// **'Bajarilgan'**
  String get assignmentsCompletedHeader;

  /// No description provided for @assignmentsOverdueChip.
  ///
  /// In uz, this message translates to:
  /// **'Muddati o\'tgan'**
  String get assignmentsOverdueChip;

  /// No description provided for @assignmentsDueTodayChip.
  ///
  /// In uz, this message translates to:
  /// **'Bugun muddati'**
  String get assignmentsDueTodayChip;

  /// No description provided for @assignmentsDueTomorrowChip.
  ///
  /// In uz, this message translates to:
  /// **'Ertaga muddati'**
  String get assignmentsDueTomorrowChip;

  /// No description provided for @assignmentsDueInDays.
  ///
  /// In uz, this message translates to:
  /// **'{days} kundan keyin'**
  String assignmentsDueInDays(int days);

  /// No description provided for @assignmentsDueOpen.
  ///
  /// In uz, this message translates to:
  /// **'Anytime'**
  String get assignmentsDueOpen;

  /// No description provided for @assignmentsCompleteCta.
  ///
  /// In uz, this message translates to:
  /// **'Bajarildi deb belgilash'**
  String get assignmentsCompleteCta;

  /// No description provided for @assignmentsStartCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni boshlash'**
  String get assignmentsStartCta;

  /// No description provided for @assignmentsCompletedAt.
  ///
  /// In uz, this message translates to:
  /// **'{date}da bajarilgan'**
  String assignmentsCompletedAt(String date);

  /// No description provided for @assignmentsTherapistNotesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Logoped izohi'**
  String get assignmentsTherapistNotesTitle;

  /// No description provided for @assignmentsCompletedToast.
  ///
  /// In uz, this message translates to:
  /// **'Vazifa bajarildi! Ajoyib! 🌟'**
  String get assignmentsCompletedToast;

  /// No description provided for @assignmentsCompleteFailed.
  ///
  /// In uz, this message translates to:
  /// **'Vazifani saqlab bo\'lmadi. Qayta urinib ko\'ring.'**
  String get assignmentsCompleteFailed;

  /// No description provided for @assignmentsOnChildTitle.
  ///
  /// In uz, this message translates to:
  /// **'Vazifalar'**
  String get assignmentsOnChildTitle;

  /// No description provided for @assignmentsOnChildEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu bola uchun hozircha vazifalar yo\'q.'**
  String get assignmentsOnChildEmpty;

  /// No description provided for @assignmentsOnChildSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasini ko\'rish'**
  String get assignmentsOnChildSeeAll;

  /// No description provided for @assignmentsScoreLabel.
  ///
  /// In uz, this message translates to:
  /// **'Bahoni qo\'shing (ixtiyoriy)'**
  String get assignmentsScoreLabel;

  /// No description provided for @assignmentsScoreSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get assignmentsScoreSave;

  /// No description provided for @assignmentsCancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get assignmentsCancel;

  /// No description provided for @speechProfileTitle.
  ///
  /// In uz, this message translates to:
  /// **'Nutq profili'**
  String get speechProfileTitle;

  /// No description provided for @speechProfileSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bola qaysi tovushlarni o\'zlashtirgan va qaysilari ustida ishlash kerakligini ko\'ring'**
  String get speechProfileSubtitle;

  /// No description provided for @speechProfileOpenCta.
  ///
  /// In uz, this message translates to:
  /// **'Nutq profilini ochish'**
  String get speechProfileOpenCta;

  /// No description provided for @speechProfileLoading.
  ///
  /// In uz, this message translates to:
  /// **'Nutq profili tayyorlanmoqda…'**
  String get speechProfileLoading;

  /// No description provided for @speechProfileErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Nutq profilini yuklab bo\'lmadi'**
  String get speechProfileErrorTitle;

  /// No description provided for @speechProfileErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get speechProfileErrorBody;

  /// No description provided for @speechProfileRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get speechProfileRetry;

  /// No description provided for @speechProfileEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha tahlil qilingan tovushlar yo\'q'**
  String get speechProfileEmptyTitle;

  /// No description provided for @speechProfileEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Bola bir nechta mashqni bajarib bo\'lganda, AI o\'zlashtirilgan va ustida ishlash kerak bo\'lgan tovushlarni ko\'rsatadi.'**
  String get speechProfileEmptyBody;

  /// No description provided for @speechProfileEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni boshlash'**
  String get speechProfileEmptyCta;

  /// No description provided for @speechProfileOverallTitle.
  ///
  /// In uz, this message translates to:
  /// **'Umumiy o\'zlashtirish'**
  String get speechProfileOverallTitle;

  /// No description provided for @speechProfileOverallSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{analysed} ta tahlil bo\'yicha o\'rtacha aniqlik'**
  String speechProfileOverallSubtitle(int analysed);

  /// No description provided for @speechProfileWindowFooter.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi {sampled} ta tahlilning {total} tasidan'**
  String speechProfileWindowFooter(int sampled, int total);

  /// No description provided for @speechProfileBucketStruggling.
  ///
  /// In uz, this message translates to:
  /// **'Diqqat kerak'**
  String get speechProfileBucketStruggling;

  /// No description provided for @speechProfileBucketDeveloping.
  ///
  /// In uz, this message translates to:
  /// **'Rivojlanmoqda'**
  String get speechProfileBucketDeveloping;

  /// No description provided for @speechProfileBucketMastered.
  ///
  /// In uz, this message translates to:
  /// **'O\'zlashtirilgan'**
  String get speechProfileBucketMastered;

  /// No description provided for @speechProfileBucketStrugglingHint.
  ///
  /// In uz, this message translates to:
  /// **'Bu tovushlar bo\'yicha mashq qilishni davom ettiring.'**
  String get speechProfileBucketStrugglingHint;

  /// No description provided for @speechProfileBucketDevelopingHint.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada mukammal bo\'ladi — yana biroz mashq.'**
  String get speechProfileBucketDevelopingHint;

  /// No description provided for @speechProfileBucketMasteredHint.
  ///
  /// In uz, this message translates to:
  /// **'Zo\'r! Bola bu tovushlarni mukammal aytadi.'**
  String get speechProfileBucketMasteredHint;

  /// No description provided for @speechProfilePhonemeTile.
  ///
  /// In uz, this message translates to:
  /// **'{phoneme} — {percent}% aniqlik'**
  String speechProfilePhonemeTile(String phoneme, int percent);

  /// No description provided for @speechProfilePhonemeSamples.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta urinish'**
  String speechProfilePhonemeSamples(int count);

  /// No description provided for @speechProfileFocusTitle.
  ///
  /// In uz, this message translates to:
  /// **'Diqqat qiling'**
  String get speechProfileFocusTitle;

  /// No description provided for @speechProfileFocusSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Eng past natija ko\'rsatgan tovushlar'**
  String get speechProfileFocusSubtitle;

  /// No description provided for @speechProfileMasteredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mukammal tovushlar'**
  String get speechProfileMasteredTitle;

  /// No description provided for @speechProfileMasteredSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bola ushbu tovushlarni mustahkam egallagan'**
  String get speechProfileMasteredSubtitle;

  /// No description provided for @speechProfileGridSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Tovushlar tabelya — {count} ta tovush'**
  String speechProfileGridSemantics(int count);

  /// No description provided for @phonemeDrillTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tovush mashqi: {phoneme}'**
  String phonemeDrillTitle(String phoneme);

  /// No description provided for @phonemeDrillHeroAccuracy.
  ///
  /// In uz, this message translates to:
  /// **'Hozirgi aniqlik'**
  String get phonemeDrillHeroAccuracy;

  /// No description provided for @phonemeDrillHeroSamples.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta urinish oxirgi tahlillarda'**
  String phonemeDrillHeroSamples(int count);

  /// No description provided for @phonemeDrillCoachStruggling.
  ///
  /// In uz, this message translates to:
  /// **'Bu tovush ustida birga ishlaymiz! Quyidagi mashqlar bola uchun maxsus tanlangan.'**
  String get phonemeDrillCoachStruggling;

  /// No description provided for @phonemeDrillCoachDeveloping.
  ///
  /// In uz, this message translates to:
  /// **'Bola yaqinda mukammal aytadi. Yana biroz mashq qilamiz!'**
  String get phonemeDrillCoachDeveloping;

  /// No description provided for @phonemeDrillCoachMastered.
  ///
  /// In uz, this message translates to:
  /// **'Zo\'r! Bola bu tovushni mukammal aytmoqda. Mahoratni saqlab turish uchun mashq qiling.'**
  String get phonemeDrillCoachMastered;

  /// No description provided for @phonemeDrillExercisesHeader.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etilgan mashqlar'**
  String get phonemeDrillExercisesHeader;

  /// No description provided for @phonemeDrillExercisesCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta mos mashq'**
  String phonemeDrillExercisesCount(int count);

  /// No description provided for @phonemeDrillStartCta.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqni boshlash'**
  String get phonemeDrillStartCta;

  /// No description provided for @phonemeDrillBrowseAll.
  ///
  /// In uz, this message translates to:
  /// **'Barcha mashqlarni ko\'rish'**
  String get phonemeDrillBrowseAll;

  /// No description provided for @phonemeDrillNoExercisesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha bu tovush bo\'yicha mashq yo\'q'**
  String get phonemeDrillNoExercisesTitle;

  /// No description provided for @phonemeDrillNoExercisesBody.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada bu tovushga maxsus mashqlar qo\'shamiz. Hozir umumiy mashqlardan foydalaning.'**
  String get phonemeDrillNoExercisesBody;

  /// No description provided for @phonemeDrillLoading.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlar tanlanmoqda…'**
  String get phonemeDrillLoading;

  /// No description provided for @phonemeDrillErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlarni yuklab bo\'lmadi'**
  String get phonemeDrillErrorTitle;

  /// No description provided for @phonemeDrillErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Aloqani tekshirib, qaytadan urinib ko\'ring.'**
  String get phonemeDrillErrorBody;

  /// No description provided for @phonemeDrillRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get phonemeDrillRetry;

  /// No description provided for @phonemeDrillBucketStruggling.
  ///
  /// In uz, this message translates to:
  /// **'Diqqat kerak'**
  String get phonemeDrillBucketStruggling;

  /// No description provided for @phonemeDrillBucketDeveloping.
  ///
  /// In uz, this message translates to:
  /// **'Rivojlanmoqda'**
  String get phonemeDrillBucketDeveloping;

  /// No description provided for @phonemeDrillBucketMastered.
  ///
  /// In uz, this message translates to:
  /// **'Mukammal'**
  String get phonemeDrillBucketMastered;

  /// No description provided for @phonemeDrillTileSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni ochish: {title}'**
  String phonemeDrillTileSemantics(String title);

  /// No description provided for @lessonPreviewTitle.
  ///
  /// In uz, this message translates to:
  /// **'Interaktiv dars'**
  String get lessonPreviewTitle;

  /// No description provided for @lessonPreviewSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bola dars davomida nima qilishini ko\'ring'**
  String get lessonPreviewSubtitle;

  /// No description provided for @lessonPreviewSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Dars rejasi — {count} ta qadam'**
  String lessonPreviewSemantics(int count);

  /// No description provided for @lessonPreviewStepsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} qadam'**
  String lessonPreviewStepsCount(int count);

  /// No description provided for @lessonStepInstruction.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'riqnoma'**
  String get lessonStepInstruction;

  /// No description provided for @lessonStepDemonstrate.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rsatish'**
  String get lessonStepDemonstrate;

  /// No description provided for @lessonStepRecord.
  ///
  /// In uz, this message translates to:
  /// **'Yozib olish'**
  String get lessonStepRecord;

  /// No description provided for @lessonStepFeedback.
  ///
  /// In uz, this message translates to:
  /// **'Natija va maqtov'**
  String get lessonStepFeedback;

  /// No description provided for @lessonStepUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa qadam'**
  String get lessonStepUnknown;

  /// No description provided for @lessonStepDurationSec.
  ///
  /// In uz, this message translates to:
  /// **'{seconds} soniya'**
  String lessonStepDurationSec(int seconds);

  /// No description provided for @lessonStepDurationRange.
  ///
  /// In uz, this message translates to:
  /// **'{min}–{max} soniya'**
  String lessonStepDurationRange(int min, int max);

  /// No description provided for @lessonStepDurationMaxOnly.
  ///
  /// In uz, this message translates to:
  /// **'Eng ko\'pi {max} soniya'**
  String lessonStepDurationMaxOnly(int max);

  /// No description provided for @lessonStepRecordTargetWord.
  ///
  /// In uz, this message translates to:
  /// **'Aytish kerak: {word}'**
  String lessonStepRecordTargetWord(String word);

  /// No description provided for @lessonStepRecordPhonemes.
  ///
  /// In uz, this message translates to:
  /// **'Tovushlar: {phonemes}'**
  String lessonStepRecordPhonemes(String phonemes);

  /// No description provided for @lessonStepInstructionFallback.
  ///
  /// In uz, this message translates to:
  /// **'Ovozli yo\'riqnoma tinglanadi.'**
  String get lessonStepInstructionFallback;

  /// No description provided for @lessonStepDemonstrateFallback.
  ///
  /// In uz, this message translates to:
  /// **'Logoped to\'g\'ri talaffuzni namoyish qiladi.'**
  String get lessonStepDemonstrateFallback;

  /// No description provided for @lessonStepRecordFallback.
  ///
  /// In uz, this message translates to:
  /// **'Bola yozib oladi.'**
  String get lessonStepRecordFallback;

  /// No description provided for @lessonStepFeedbackFallback.
  ///
  /// In uz, this message translates to:
  /// **'Natija va maqtov ko\'rsatiladi.'**
  String get lessonStepFeedbackFallback;

  /// No description provided for @lessonPreviewMascotIntro.
  ///
  /// In uz, this message translates to:
  /// **'Bu darsda bola {steps} qadamdan o\'tadi va to\'g\'ri talaffuzni mashq qiladi.'**
  String lessonPreviewMascotIntro(int steps);

  /// No description provided for @lessonPlayerStepCounter.
  ///
  /// In uz, this message translates to:
  /// **'Qadam {current} / {total}'**
  String lessonPlayerStepCounter(int current, int total);

  /// No description provided for @lessonPlayerNext.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get lessonPlayerNext;

  /// No description provided for @lessonPlayerSkip.
  ///
  /// In uz, this message translates to:
  /// **'O\'tkazib yuborish'**
  String get lessonPlayerSkip;

  /// No description provided for @lessonPlayerFinish.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlash'**
  String get lessonPlayerFinish;

  /// No description provided for @lessonPlayerExitTitle.
  ///
  /// In uz, this message translates to:
  /// **'Darsdan chiqish?'**
  String get lessonPlayerExitTitle;

  /// No description provided for @lessonPlayerExitBody.
  ///
  /// In uz, this message translates to:
  /// **'Boshlangan dars saqlanmaydi va qaytadan boshlanadi.'**
  String get lessonPlayerExitBody;

  /// No description provided for @lessonPlayerExitConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get lessonPlayerExitConfirm;

  /// No description provided for @lessonPlayerExitCancel.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get lessonPlayerExitCancel;

  /// No description provided for @lessonPlayerInstructionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'riqnoma'**
  String get lessonPlayerInstructionTitle;

  /// No description provided for @lessonPlayerDemonstrateTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tinglash'**
  String get lessonPlayerDemonstrateTitle;

  /// No description provided for @lessonPlayerDemonstrateHint.
  ///
  /// In uz, this message translates to:
  /// **'Audio namunani diqqat bilan tinglang'**
  String get lessonPlayerDemonstrateHint;

  /// No description provided for @lessonPlayerRecordTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yozib olish'**
  String get lessonPlayerRecordTitle;

  /// No description provided for @lessonPlayerRecordHint.
  ///
  /// In uz, this message translates to:
  /// **'Tugmani bosing va aniq aytib bering'**
  String get lessonPlayerRecordHint;

  /// No description provided for @lessonPlayerRecordReadyHint.
  ///
  /// In uz, this message translates to:
  /// **'Yozib olindi! Yana tinglash mumkin yoki keyingi qadamga o\'ting.'**
  String get lessonPlayerRecordReadyHint;

  /// No description provided for @lessonPlayerFeedbackTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yakun'**
  String get lessonPlayerFeedbackTitle;

  /// No description provided for @lessonPlayerEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu darsda interaktiv qadamlar mavjud emas.'**
  String get lessonPlayerEmpty;

  /// No description provided for @lessonPlayerSubmitting.
  ///
  /// In uz, this message translates to:
  /// **'Natijani yuborish...'**
  String get lessonPlayerSubmitting;

  /// No description provided for @lessonPlayerStarting.
  ///
  /// In uz, this message translates to:
  /// **'Dars tayyorlanmoqda...'**
  String get lessonPlayerStarting;

  /// No description provided for @lessonPlayerCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Ajoyib! Dars yakunlandi 🎉'**
  String get lessonPlayerCompleted;

  /// No description provided for @lessonPlayerProgressSemantics.
  ///
  /// In uz, this message translates to:
  /// **'Dars davom etmoqda: {current} qadam {total} dan'**
  String lessonPlayerProgressSemantics(int current, int total);

  /// No description provided for @exerciseLoadFailed.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni yuklashda xato yuz berdi'**
  String get exerciseLoadFailed;

  /// No description provided for @exerciseNoSteps.
  ///
  /// In uz, this message translates to:
  /// **'Bu mashqda interaktiv qadamlar yo\'q. Mashq sahifasiga qayting.'**
  String get exerciseNoSteps;

  /// No description provided for @helpAndTips.
  ///
  /// In uz, this message translates to:
  /// **'Yordam va maslahatlar'**
  String get helpAndTips;

  /// No description provided for @helpAndTipsHint.
  ///
  /// In uz, this message translates to:
  /// **'Tez-tez beriladigan savollar va uy mashg\'uloti bo\'yicha maslahatlar'**
  String get helpAndTipsHint;

  /// No description provided for @helpTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yordam markazi'**
  String get helpTitle;

  /// No description provided for @helpHeroTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sizga yordam berish uchun shu yerdamiz'**
  String get helpHeroTitle;

  /// No description provided for @helpHeroSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Quyida ko\'p so\'raladigan savollar javoblari va kundalik mashqlar uchun amaliy maslahatlar mavjud.'**
  String get helpHeroSubtitle;

  /// No description provided for @helpFaqSectionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tez-tez beriladigan savollar'**
  String get helpFaqSectionTitle;

  /// No description provided for @helpTipsSectionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Uydagi mashg\'ulot uchun maslahatlar'**
  String get helpTipsSectionTitle;

  /// No description provided for @helpDisclaimerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Eslatma'**
  String get helpDisclaimerTitle;

  /// No description provided for @helpDisclaimerBody.
  ///
  /// In uz, this message translates to:
  /// **'SADO — bu skrining va mashq vositasi. Tashxis qo\'yish va davolashga oid qarorlarni faqat malakali logoped yoki shifokor qabul qiladi. Agar siz xavotirga tushsangiz, mutaxassisga murojaat qiling.'**
  String get helpDisclaimerBody;

  /// No description provided for @helpFaq1Q.
  ///
  /// In uz, this message translates to:
  /// **'SADO bolaning nutqini qanday baholaydi?'**
  String get helpFaq1Q;

  /// No description provided for @helpFaq1A.
  ///
  /// In uz, this message translates to:
  /// **'Mobil ilova qisqa audio yozuvni oladi va talaffuz, ravonlik hamda nutq sur\'atini o\'zbek va rus tillaridagi yosh me\'yorlari asosida sun\'iy intellekt yordamida tahlil qiladi. Natija o\'rtacha 5–15 soniyada tayyor bo\'ladi.'**
  String get helpFaq1A;

  /// No description provided for @helpFaq2Q.
  ///
  /// In uz, this message translates to:
  /// **'Bola qancha mashq qilishi kerak?'**
  String get helpFaq2Q;

  /// No description provided for @helpFaq2A.
  ///
  /// In uz, this message translates to:
  /// **'Kuniga 5–10 daqiqa yetarli. Mashqning davomiyligidan ko\'ra, ularning muntazamligi muhimroq. Bosh sahifadagi seriya (streak) belgisi siz bilan birga sanab boradi.'**
  String get helpFaq2A;

  /// No description provided for @helpFaq3Q.
  ///
  /// In uz, this message translates to:
  /// **'Yashil, sariq va qizil ranglar nima ma\'noni anglatadi?'**
  String get helpFaq3Q;

  /// No description provided for @helpFaq3A.
  ///
  /// In uz, this message translates to:
  /// **'Yashil — yoshiga mos rivojlanish; Sariq — kuzatish kerak bo\'lgan ba\'zi belgilar; Qizil — mutaxassisga murojaat qilish tavsiya etiladi. SADO tashxis emas, balki dastlabki belgi beruvchi vositadir.'**
  String get helpFaq3A;

  /// No description provided for @helpFaq4Q.
  ///
  /// In uz, this message translates to:
  /// **'Bola yolg\'iz mashq qila oladimi?'**
  String get helpFaq4Q;

  /// No description provided for @helpFaq4A.
  ///
  /// In uz, this message translates to:
  /// **'5 yoshdan katta bolalar mustaqil ishlay oladi. Kichikroqlarga esa yonida o\'tirib rag\'batlantirib turuvchi ota-ona kerak — bu natijaning aniqligini ham oshiradi.'**
  String get helpFaq4A;

  /// No description provided for @helpFaq5Q.
  ///
  /// In uz, this message translates to:
  /// **'Ball oshmayapti — nima qilay?'**
  String get helpFaq5Q;

  /// No description provided for @helpFaq5A.
  ///
  /// In uz, this message translates to:
  /// **'Tinch xona tanlang, sekinroq aytib bering, va natijadan ko\'ra harakatni maqtang. Agar 2 hafta davomida o\'zgarish bo\'lmasa, logopedga ko\'rinishni rejalashtiring.'**
  String get helpFaq5A;

  /// No description provided for @helpFaq6Q.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvlar maxfiyligi qanday ta\'minlanadi?'**
  String get helpFaq6Q;

  /// No description provided for @helpFaq6A.
  ///
  /// In uz, this message translates to:
  /// **'Audio fayllari shifrlangan kanal orqali yuboriladi va faqat sizning bolangizning natijasini hisoblash uchun ishlatiladi. Uchinchi shaxslar bilan ulashilmaydi.'**
  String get helpFaq6A;

  /// No description provided for @helpTip1Title.
  ///
  /// In uz, this message translates to:
  /// **'Tinch muhitni tanlang'**
  String get helpTip1Title;

  /// No description provided for @helpTip1Body.
  ///
  /// In uz, this message translates to:
  /// **'Televizor va boshqa shovqinlarni o\'chiring. Sokin xona mikrofonga toza ovoz beradi va bola e\'tiborini saqlashga yordam beradi.'**
  String get helpTip1Body;

  /// No description provided for @helpTip2Title.
  ///
  /// In uz, this message translates to:
  /// **'Natijadan ko\'ra harakatni maqtang'**
  String get helpTip2Title;

  /// No description provided for @helpTip2Body.
  ///
  /// In uz, this message translates to:
  /// **'“Sen astoydil harakat qilding” — bu “sen yutding” dan kuchliroq. Bola qiyin tovushga ham qaytishni xohlaydi.'**
  String get helpTip2Body;

  /// No description provided for @helpTip3Title.
  ///
  /// In uz, this message translates to:
  /// **'Birga aytib bering'**
  String get helpTip3Title;

  /// No description provided for @helpTip3Body.
  ///
  /// In uz, this message translates to:
  /// **'Mashq oldidan so\'zni o\'zingiz aniq aytib, og\'iz harakatini ko\'rsating. Bola sizga taqlid qilib o\'rganadi.'**
  String get helpTip3Body;

  /// No description provided for @helpTip4Title.
  ///
  /// In uz, this message translates to:
  /// **'Qisqa va o\'yinli qiling'**
  String get helpTip4Title;

  /// No description provided for @helpTip4Body.
  ///
  /// In uz, this message translates to:
  /// **'Bir mashg\'ulot 5–10 daqiqadan oshmasin. Bola charchasa, ertaga davom eting — seriya saqlanadi.'**
  String get helpTip4Body;

  /// No description provided for @helpTip5Title.
  ///
  /// In uz, this message translates to:
  /// **'Seriyalarni nishonlang'**
  String get helpTip5Title;

  /// No description provided for @helpTip5Body.
  ///
  /// In uz, this message translates to:
  /// **'Har 7 kunlik seriya uchun kichik bir o\'yin yoki sayr — bola uchun ulkan motivatsiya. Nishonlarni birga oching.'**
  String get helpTip5Body;

  /// No description provided for @practiceCalendarTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mashq taqvimi'**
  String get practiceCalendarTitle;

  /// No description provided for @practiceCalendarEntryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mashq taqvimi'**
  String get practiceCalendarEntryTitle;

  /// No description provided for @practiceCalendarEntrySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bola qaysi kunlari mashq qilganini ko\'ring'**
  String get practiceCalendarEntrySubtitle;

  /// No description provided for @practiceCalendarStatsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bu oyning natijalari'**
  String get practiceCalendarStatsTitle;

  /// No description provided for @practiceCalendarStatsSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Joriy seriya: {streak, plural, =0{tanaffus} =1{1 kun} other{{streak} kun}}'**
  String practiceCalendarStatsSubtitle(int streak);

  /// No description provided for @practiceCalendarStatActiveDays.
  ///
  /// In uz, this message translates to:
  /// **'Mashq qilingan kunlar'**
  String get practiceCalendarStatActiveDays;

  /// No description provided for @practiceCalendarStatSessions.
  ///
  /// In uz, this message translates to:
  /// **'Jami mashqlar'**
  String get practiceCalendarStatSessions;

  /// No description provided for @practiceCalendarStatAvgScore.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha ball'**
  String get practiceCalendarStatAvgScore;

  /// No description provided for @practiceCalendarPrevMonth.
  ///
  /// In uz, this message translates to:
  /// **'Oldingi oy'**
  String get practiceCalendarPrevMonth;

  /// No description provided for @practiceCalendarNextMonth.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi oy'**
  String get practiceCalendarNextMonth;

  /// No description provided for @practiceCalendarEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hali mashqlar yo\'q'**
  String get practiceCalendarEmptyTitle;

  /// No description provided for @practiceCalendarEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqdan so\'ng taqvim yulduzlar bilan to\'lib boradi'**
  String get practiceCalendarEmptyBody;

  /// No description provided for @practiceCalendarEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni boshlash'**
  String get practiceCalendarEmptyCta;

  /// No description provided for @practiceCalendarErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Taqvimni yuklab bo\'lmadi'**
  String get practiceCalendarErrorTitle;

  /// No description provided for @practiceCalendarErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internetni tekshirib, qayta urinib ko\'ring'**
  String get practiceCalendarErrorBody;

  /// No description provided for @practiceCalendarLegendTitle.
  ///
  /// In uz, this message translates to:
  /// **'Faollik'**
  String get practiceCalendarLegendTitle;

  /// No description provided for @practiceCalendarDayLabel.
  ///
  /// In uz, this message translates to:
  /// **'{date}: {count, plural, =0{mashq yo\'q} =1{1 mashq} other{{count} mashq}}'**
  String practiceCalendarDayLabel(String date, int count);

  /// No description provided for @practiceCalendarDaySessionsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Mashq qilinmagan kun} =1{1 mashq} other{{count} mashq}}'**
  String practiceCalendarDaySessionsCount(int count);

  /// No description provided for @practiceCalendarDayEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu kuni mashq qilinmagan. Bugun davom ettiring!'**
  String get practiceCalendarDayEmpty;

  /// No description provided for @practicePlansTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mashq rejalari'**
  String get practicePlansTitle;

  /// No description provided for @practicePlansSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Logoped tomonidan tuzilgan kundalik mashqlar'**
  String get practicePlansSubtitle;

  /// No description provided for @practicePlansHomeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Faol reja'**
  String get practicePlansHomeTitle;

  /// No description provided for @practicePlansHomeBody.
  ///
  /// In uz, this message translates to:
  /// **'{count} tadan {done} ta mashq bajarildi'**
  String practicePlansHomeBody(int done, int count);

  /// No description provided for @practicePlansHomeOpen.
  ///
  /// In uz, this message translates to:
  /// **'Rejani ochish'**
  String get practicePlansHomeOpen;

  /// No description provided for @practicePlansEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha rejalar yo\'q'**
  String get practicePlansEmptyTitle;

  /// No description provided for @practicePlansEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Baholash yakunlangach, AI shaxsiy mashq rejasini taklif qiladi.'**
  String get practicePlansEmptyBody;

  /// No description provided for @practicePlansEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Baholashni boshlash'**
  String get practicePlansEmptyCta;

  /// No description provided for @practicePlansErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rejalarni yuklab bo\'lmadi'**
  String get practicePlansErrorTitle;

  /// No description provided for @practicePlansErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internetni tekshirib, qayta urinib ko\'ring.'**
  String get practicePlansErrorBody;

  /// No description provided for @practicePlansRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinib ko\'rish'**
  String get practicePlansRetry;

  /// No description provided for @practicePlansLoading.
  ///
  /// In uz, this message translates to:
  /// **'Rejalar yuklanmoqda…'**
  String get practicePlansLoading;

  /// No description provided for @practicePlansActiveHeader.
  ///
  /// In uz, this message translates to:
  /// **'Faol rejalar'**
  String get practicePlansActiveHeader;

  /// No description provided for @practicePlansDraftHeader.
  ///
  /// In uz, this message translates to:
  /// **'Loyihalar'**
  String get practicePlansDraftHeader;

  /// No description provided for @practicePlansCompletedHeader.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlanganlar'**
  String get practicePlansCompletedHeader;

  /// No description provided for @practicePlansArchivedHeader.
  ///
  /// In uz, this message translates to:
  /// **'Arxiv'**
  String get practicePlansArchivedHeader;

  /// No description provided for @practicePlansItemsCount.
  ///
  /// In uz, this message translates to:
  /// **'{done}/{count}'**
  String practicePlansItemsCount(int done, int count);

  /// No description provided for @practicePlansItemsLabel.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{mashq yo\'q} =1{1 mashq} other{{count} mashq}}'**
  String practicePlansItemsLabel(int count);

  /// No description provided for @practicePlanStatusDraft.
  ///
  /// In uz, this message translates to:
  /// **'Loyiha'**
  String get practicePlanStatusDraft;

  /// No description provided for @practicePlanStatusActive.
  ///
  /// In uz, this message translates to:
  /// **'Faol'**
  String get practicePlanStatusActive;

  /// No description provided for @practicePlanStatusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan'**
  String get practicePlanStatusCompleted;

  /// No description provided for @practicePlanStatusArchived.
  ///
  /// In uz, this message translates to:
  /// **'Arxiv'**
  String get practicePlanStatusArchived;

  /// No description provided for @practicePlanFocusHeader.
  ///
  /// In uz, this message translates to:
  /// **'E\'tibor qaratiladigan tovushlar'**
  String get practicePlanFocusHeader;

  /// No description provided for @practicePlanItemsHeader.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlar'**
  String get practicePlanItemsHeader;

  /// No description provided for @practicePlanHistoryHeader.
  ///
  /// In uz, this message translates to:
  /// **'Bajarilgan mashqlar'**
  String get practicePlanHistoryHeader;

  /// No description provided for @practicePlanItemPriority.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi navbatda'**
  String get practicePlanItemPriority;

  /// No description provided for @practicePlanItemDoneCta.
  ///
  /// In uz, this message translates to:
  /// **'+1 marta'**
  String get practicePlanItemDoneCta;

  /// No description provided for @practicePlanItemFinishedCta.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlandi'**
  String get practicePlanItemFinishedCta;

  /// No description provided for @practicePlanItemSkipCta.
  ///
  /// In uz, this message translates to:
  /// **'O\'tkazib yuborish'**
  String get practicePlanItemSkipCta;

  /// No description provided for @practicePlanItemProgressLabel.
  ///
  /// In uz, this message translates to:
  /// **'Muvaffaqiyat: {done}/{count}'**
  String practicePlanItemProgressLabel(int done, int count);

  /// No description provided for @practicePlanItemRecordedToast.
  ///
  /// In uz, this message translates to:
  /// **'Mashq qayd etildi! 🌟'**
  String get practicePlanItemRecordedToast;

  /// No description provided for @practicePlanItemSkippedToast.
  ///
  /// In uz, this message translates to:
  /// **'Mashq o\'tkazib yuborildi.'**
  String get practicePlanItemSkippedToast;

  /// No description provided for @practicePlanItemFailedToast.
  ///
  /// In uz, this message translates to:
  /// **'Saqlab bo\'lmadi. Qayta urinib ko\'ring.'**
  String get practicePlanItemFailedToast;

  /// No description provided for @practicePlanGenerateCta.
  ///
  /// In uz, this message translates to:
  /// **'AI yordamida reja yaratish'**
  String get practicePlanGenerateCta;

  /// No description provided for @practicePlanGenerateLoading.
  ///
  /// In uz, this message translates to:
  /// **'Reja tayyorlanmoqda…'**
  String get practicePlanGenerateLoading;

  /// No description provided for @practicePlanGenerateSuccess.
  ///
  /// In uz, this message translates to:
  /// **'Yangi reja tayyor! 🎉'**
  String get practicePlanGenerateSuccess;

  /// No description provided for @practicePlanGenerateFailed.
  ///
  /// In uz, this message translates to:
  /// **'Rejani yaratib bo\'lmadi.'**
  String get practicePlanGenerateFailed;

  /// No description provided for @practicePlanDateRange.
  ///
  /// In uz, this message translates to:
  /// **'{start} – {end}'**
  String practicePlanDateRange(String start, String end);

  /// No description provided for @practicePlanStartedOn.
  ///
  /// In uz, this message translates to:
  /// **'Boshlangan: {date}'**
  String practicePlanStartedOn(String date);

  /// No description provided for @practicePlanCompletedOn.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan: {date}'**
  String practicePlanCompletedOn(String date);

  /// No description provided for @practicePlanProgressTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bajarilish'**
  String get practicePlanProgressTitle;

  /// No description provided for @practicePlanItemNoExerciseTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mashq'**
  String get practicePlanItemNoExerciseTitle;

  /// No description provided for @practicePlanItemEmptyHistory.
  ///
  /// In uz, this message translates to:
  /// **'Hali bajarilgan mashqlar yo\'q.'**
  String get practicePlanItemEmptyHistory;

  /// No description provided for @practicePlanOpenExerciseCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqni ochish'**
  String get practicePlanOpenExerciseCta;

  /// No description provided for @timelineTitle.
  ///
  /// In uz, this message translates to:
  /// **'Faollik tarixi'**
  String get timelineTitle;

  /// No description provided for @timelineSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bolaning so\'nggi yutuqlari'**
  String get timelineSubtitle;

  /// No description provided for @timelineLoading.
  ///
  /// In uz, this message translates to:
  /// **'Tarix yuklanmoqda…'**
  String get timelineLoading;

  /// No description provided for @timelineErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tarixni yuklab bo\'lmadi'**
  String get timelineErrorTitle;

  /// No description provided for @timelineErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get timelineErrorBody;

  /// No description provided for @timelineRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get timelineRetry;

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hali faollik yo\'q'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqdan keyin bu yerda bolaning yutuqlari ko\'rinadi.'**
  String get timelineEmptyBody;

  /// No description provided for @timelineEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlarni ochish'**
  String get timelineEmptyCta;

  /// No description provided for @timelineAssessmentLabel.
  ///
  /// In uz, this message translates to:
  /// **'Baholash'**
  String get timelineAssessmentLabel;

  /// No description provided for @timelineAssessmentSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{childName} • Ovoz tahlili'**
  String timelineAssessmentSubtitle(String childName);

  /// No description provided for @timelineAssessmentScore.
  ///
  /// In uz, this message translates to:
  /// **'{score}%'**
  String timelineAssessmentScore(int score);

  /// No description provided for @timelineAssessmentNoScore.
  ///
  /// In uz, this message translates to:
  /// **'Tahlil qilinmoqda'**
  String get timelineAssessmentNoScore;

  /// No description provided for @timelineAssignmentLabel.
  ///
  /// In uz, this message translates to:
  /// **'Vazifa bajarildi'**
  String get timelineAssignmentLabel;

  /// No description provided for @timelineAssignmentSubtitleNamed.
  ///
  /// In uz, this message translates to:
  /// **'{childName} • {title}'**
  String timelineAssignmentSubtitleNamed(String childName, String title);

  /// No description provided for @timelineAssignmentSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{childName} • Mashq'**
  String timelineAssignmentSubtitle(String childName);

  /// No description provided for @timelineUnknownChild.
  ///
  /// In uz, this message translates to:
  /// **'Bola'**
  String get timelineUnknownChild;

  /// No description provided for @timelineSectionThisWeek.
  ///
  /// In uz, this message translates to:
  /// **'Shu hafta'**
  String get timelineSectionThisWeek;

  /// No description provided for @timelineSectionEarlier.
  ///
  /// In uz, this message translates to:
  /// **'Avvalroq'**
  String get timelineSectionEarlier;

  /// No description provided for @profileMenuTimeline.
  ///
  /// In uz, this message translates to:
  /// **'Faollik tarixi'**
  String get profileMenuTimeline;

  /// No description provided for @recordingsHistoryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz yozuvlari'**
  String get recordingsHistoryTitle;

  /// No description provided for @recordingsHistorySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bolaning so\'nggi yozilgan ovozlari'**
  String get recordingsHistorySubtitle;

  /// No description provided for @recordingsHistoryLoading.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvlar yuklanmoqda…'**
  String get recordingsHistoryLoading;

  /// No description provided for @recordingsHistoryErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvlarni yuklab bo\'lmadi'**
  String get recordingsHistoryErrorTitle;

  /// No description provided for @recordingsHistoryErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get recordingsHistoryErrorBody;

  /// No description provided for @recordingsHistoryRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get recordingsHistoryRetry;

  /// No description provided for @recordingsHistoryEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hali yozuvlar yo\'q'**
  String get recordingsHistoryEmptyTitle;

  /// No description provided for @recordingsHistoryEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Birinchi mashqdan keyin bolaning yozilgan ovozlari shu yerda saqlanadi.'**
  String get recordingsHistoryEmptyBody;

  /// No description provided for @recordingsHistoryEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Mashqlarni ochish'**
  String get recordingsHistoryEmptyCta;

  /// No description provided for @recordingsHistorySectionToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun'**
  String get recordingsHistorySectionToday;

  /// No description provided for @recordingsHistorySectionThisWeek.
  ///
  /// In uz, this message translates to:
  /// **'Shu hafta'**
  String get recordingsHistorySectionThisWeek;

  /// No description provided for @recordingsHistorySectionThisMonth.
  ///
  /// In uz, this message translates to:
  /// **'Shu oy'**
  String get recordingsHistorySectionThisMonth;

  /// No description provided for @recordingsHistorySectionEarlier.
  ///
  /// In uz, this message translates to:
  /// **'Avvalroq'**
  String get recordingsHistorySectionEarlier;

  /// No description provided for @recordingsHistoryPlayLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ovozni eshitish'**
  String get recordingsHistoryPlayLabel;

  /// No description provided for @recordingsHistoryPlayError.
  ///
  /// In uz, this message translates to:
  /// **'Audio yuklab bo\'lmadi'**
  String get recordingsHistoryPlayError;

  /// No description provided for @recordingsHistoryViewDetails.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil natija'**
  String get recordingsHistoryViewDetails;

  /// No description provided for @recordingsHistoryNoAudio.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu baholashda yozuv yo\'q'**
  String get recordingsHistoryNoAudio;

  /// No description provided for @recordingsHistoryEntryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz yozuvlari'**
  String get recordingsHistoryEntryTitle;

  /// No description provided for @recordingsHistoryEntrySubtitleEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali yozuvlar yo\'q'**
  String get recordingsHistoryEntrySubtitleEmpty;

  /// No description provided for @recordingsHistoryEntrySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 yozuv saqlangan} other{{count} ta yozuv saqlangan}}'**
  String recordingsHistoryEntrySubtitle(int count);

  /// No description provided for @tipOfTheDayLabel.
  ///
  /// In uz, this message translates to:
  /// **'BUGUNGI MASLAHAT'**
  String get tipOfTheDayLabel;

  /// No description provided for @subscriptionTitle.
  ///
  /// In uz, this message translates to:
  /// **'SADO Premium'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz mashq, to\'liq tahlil va batafsil taraqqiyot'**
  String get subscriptionSubtitle;

  /// No description provided for @subscriptionMascotMessage.
  ///
  /// In uz, this message translates to:
  /// **'Premium bilan barcha imkoniyatlar ochiladi!'**
  String get subscriptionMascotMessage;

  /// No description provided for @subscriptionCurrentPlanLabel.
  ///
  /// In uz, this message translates to:
  /// **'Sizning rejangiz'**
  String get subscriptionCurrentPlanLabel;

  /// No description provided for @subscriptionCurrentBadge.
  ///
  /// In uz, this message translates to:
  /// **'Joriy'**
  String get subscriptionCurrentBadge;

  /// No description provided for @subscriptionRecommendedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etiladi'**
  String get subscriptionRecommendedBadge;

  /// No description provided for @subscriptionFreeName.
  ///
  /// In uz, this message translates to:
  /// **'Bepul'**
  String get subscriptionFreeName;

  /// No description provided for @subscriptionProName.
  ///
  /// In uz, this message translates to:
  /// **'Premium'**
  String get subscriptionProName;

  /// No description provided for @subscriptionLogopedName.
  ///
  /// In uz, this message translates to:
  /// **'Logoped'**
  String get subscriptionLogopedName;

  /// No description provided for @subscriptionClinicName.
  ///
  /// In uz, this message translates to:
  /// **'Klinika'**
  String get subscriptionClinicName;

  /// No description provided for @subscriptionClinicPremiumName.
  ///
  /// In uz, this message translates to:
  /// **'Klinika Premium'**
  String get subscriptionClinicPremiumName;

  /// No description provided for @subscriptionUnknownPlanName.
  ///
  /// In uz, this message translates to:
  /// **'Reja'**
  String get subscriptionUnknownPlanName;

  /// No description provided for @subscriptionFreeTagline.
  ///
  /// In uz, this message translates to:
  /// **'Boshlash uchun ajoyib reja'**
  String get subscriptionFreeTagline;

  /// No description provided for @subscriptionProTagline.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz mashq va sun\'iy intellekt tahlili'**
  String get subscriptionProTagline;

  /// No description provided for @subscriptionLogopedTagline.
  ///
  /// In uz, this message translates to:
  /// **'Mutaxassislar uchun bemorlarni boshqarish'**
  String get subscriptionLogopedTagline;

  /// No description provided for @subscriptionClinicTagline.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'cha va klinikalar uchun tenant rejasi'**
  String get subscriptionClinicTagline;

  /// No description provided for @subscriptionClinicPremiumTagline.
  ///
  /// In uz, this message translates to:
  /// **'Kengaytirilgan klinikalar uchun premium imkoniyatlar'**
  String get subscriptionClinicPremiumTagline;

  /// No description provided for @subscriptionPriceFree.
  ///
  /// In uz, this message translates to:
  /// **'Bepul'**
  String get subscriptionPriceFree;

  /// No description provided for @subscriptionPricePerMonth.
  ///
  /// In uz, this message translates to:
  /// **'{price} so\'m/oy'**
  String subscriptionPricePerMonth(String price);

  /// No description provided for @subscriptionPricePerMonthUsd.
  ///
  /// In uz, this message translates to:
  /// **'≈ \${usd}/oy'**
  String subscriptionPricePerMonthUsd(String usd);

  /// No description provided for @subscriptionFeatureBasicExercises.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy mashqlar'**
  String get subscriptionFeatureBasicExercises;

  /// No description provided for @subscriptionFeatureBasicProgress.
  ///
  /// In uz, this message translates to:
  /// **'Oddiy taraqqiyot'**
  String get subscriptionFeatureBasicProgress;

  /// No description provided for @subscriptionFeatureExerciseLimit.
  ///
  /// In uz, this message translates to:
  /// **'Kuniga {count} ta mashq'**
  String subscriptionFeatureExerciseLimit(int count);

  /// No description provided for @subscriptionFeatureAiLimit.
  ///
  /// In uz, this message translates to:
  /// **'Oyiga {count} ta AI tahlil'**
  String subscriptionFeatureAiLimit(int count);

  /// No description provided for @subscriptionFeatureChildLimit.
  ///
  /// In uz, this message translates to:
  /// **'{count} bola'**
  String subscriptionFeatureChildLimit(int count);

  /// No description provided for @subscriptionFeatureUnlimitedExercises.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz mashq'**
  String get subscriptionFeatureUnlimitedExercises;

  /// No description provided for @subscriptionFeatureUnlimitedAi.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz AI tahlil'**
  String get subscriptionFeatureUnlimitedAi;

  /// No description provided for @subscriptionFeatureMultipleChildren.
  ///
  /// In uz, this message translates to:
  /// **'{count} tagacha bola'**
  String subscriptionFeatureMultipleChildren(int count);

  /// No description provided for @subscriptionFeatureDetailedProgress.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil taraqqiyot'**
  String get subscriptionFeatureDetailedProgress;

  /// No description provided for @subscriptionFeatureRecommendations.
  ///
  /// In uz, this message translates to:
  /// **'Shaxsiy tavsiyalar'**
  String get subscriptionFeatureRecommendations;

  /// No description provided for @subscriptionFeatureExportPdf.
  ///
  /// In uz, this message translates to:
  /// **'PDF eksport'**
  String get subscriptionFeatureExportPdf;

  /// No description provided for @subscriptionFeaturePatientManagement.
  ///
  /// In uz, this message translates to:
  /// **'Bemorlarni boshqarish'**
  String get subscriptionFeaturePatientManagement;

  /// No description provided for @subscriptionFeatureAssignExercises.
  ///
  /// In uz, this message translates to:
  /// **'Mashq biriktirish'**
  String get subscriptionFeatureAssignExercises;

  /// No description provided for @subscriptionFeatureTherapyGoals.
  ///
  /// In uz, this message translates to:
  /// **'Davolash maqsadlari'**
  String get subscriptionFeatureTherapyGoals;

  /// No description provided for @subscriptionFeatureScreeningBattery.
  ///
  /// In uz, this message translates to:
  /// **'Skrining to\'plami'**
  String get subscriptionFeatureScreeningBattery;

  /// No description provided for @subscriptionFeatureReferralPdf.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'llanma (PDF)'**
  String get subscriptionFeatureReferralPdf;

  /// No description provided for @subscriptionFeatureAnalytics.
  ///
  /// In uz, this message translates to:
  /// **'Analitika'**
  String get subscriptionFeatureAnalytics;

  /// No description provided for @subscriptionFeaturePatientLimit.
  ///
  /// In uz, this message translates to:
  /// **'{count} tagacha bemor'**
  String subscriptionFeaturePatientLimit(int count);

  /// No description provided for @subscriptionUpgradeCta.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tish'**
  String get subscriptionUpgradeCta;

  /// No description provided for @subscriptionContinueFree.
  ///
  /// In uz, this message translates to:
  /// **'Bepul rejada davom etish'**
  String get subscriptionContinueFree;

  /// No description provided for @subscriptionContactSales.
  ///
  /// In uz, this message translates to:
  /// **'Logoped uchun bog\'lanish'**
  String get subscriptionContactSales;

  /// No description provided for @subscriptionComingSoonTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada!'**
  String get subscriptionComingSoonTitle;

  /// No description provided for @subscriptionComingSoonBody.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovlar tizimi tayyorlanmoqda. Birinchilardan bo\'lib xabardor bo\'lish uchun bizga yozing.'**
  String get subscriptionComingSoonBody;

  /// No description provided for @subscriptionComingSoonClose.
  ///
  /// In uz, this message translates to:
  /// **'Tushundim'**
  String get subscriptionComingSoonClose;

  /// No description provided for @subscriptionContactSalesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mutaxassislar uchun reja'**
  String get subscriptionContactSalesTitle;

  /// No description provided for @subscriptionContactSalesIntro.
  ///
  /// In uz, this message translates to:
  /// **'{planName} reja maxsus narxlash bilan beriladi. Sotuv jamoamizga yozing yoki qo\'ng\'iroq qiling — sizga yarim soat ichida javob beramiz.'**
  String subscriptionContactSalesIntro(String planName);

  /// No description provided for @subscriptionContactSalesEmailLabel.
  ///
  /// In uz, this message translates to:
  /// **'Elektron pochta'**
  String get subscriptionContactSalesEmailLabel;

  /// No description provided for @subscriptionContactSalesPhoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Telefon'**
  String get subscriptionContactSalesPhoneLabel;

  /// No description provided for @subscriptionContactSalesEmail.
  ///
  /// In uz, this message translates to:
  /// **'sales@sado.uz'**
  String get subscriptionContactSalesEmail;

  /// No description provided for @subscriptionContactSalesPhone.
  ///
  /// In uz, this message translates to:
  /// **'+998 71 200 00 00'**
  String get subscriptionContactSalesPhone;

  /// No description provided for @subscriptionContactSalesEmailCta.
  ///
  /// In uz, this message translates to:
  /// **'Email yozish'**
  String get subscriptionContactSalesEmailCta;

  /// No description provided for @subscriptionContactSalesPhoneCta.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq qilish'**
  String get subscriptionContactSalesPhoneCta;

  /// No description provided for @subscriptionContactSalesCopyTooltip.
  ///
  /// In uz, this message translates to:
  /// **'Nusxa olish'**
  String get subscriptionContactSalesCopyTooltip;

  /// No description provided for @subscriptionContactSalesCopiedSnack.
  ///
  /// In uz, this message translates to:
  /// **'Nusxa olindi'**
  String get subscriptionContactSalesCopiedSnack;

  /// No description provided for @subscriptionContactSalesEmailSubject.
  ///
  /// In uz, this message translates to:
  /// **'{planName} reja haqida so\'rov'**
  String subscriptionContactSalesEmailSubject(String planName);

  /// No description provided for @subscriptionContactSalesEmailBody.
  ///
  /// In uz, this message translates to:
  /// **'Salom! Men SADO ilovasi orqali {planName} rejasi haqida ko\'proq ma\'lumot olmoqchiman.\n\nKompaniya / shifoxona:\nMutaxassislar soni:\nQulay vaqt:\n'**
  String subscriptionContactSalesEmailBody(String planName);

  /// No description provided for @subscriptionContactSalesClose.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get subscriptionContactSalesClose;

  /// No description provided for @subscriptionLoadingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rejalar yuklanmoqda…'**
  String get subscriptionLoadingTitle;

  /// No description provided for @subscriptionErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rejalarni yuklab bo\'lmadi'**
  String get subscriptionErrorTitle;

  /// No description provided for @subscriptionErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internetni tekshirib, qayta urinib ko\'ring.'**
  String get subscriptionErrorBody;

  /// No description provided for @subscriptionErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get subscriptionErrorRetry;

  /// No description provided for @subscriptionEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha rejalar yo\'q'**
  String get subscriptionEmptyTitle;

  /// No description provided for @subscriptionEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada yangi tariflar qo\'shiladi.'**
  String get subscriptionEmptyBody;

  /// No description provided for @subscriptionFooterNote.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov xavfsiz amalga oshiriladi. Istalgan vaqtda bekor qilishingiz mumkin.'**
  String get subscriptionFooterNote;

  /// No description provided for @subscriptionMenuRow.
  ///
  /// In uz, this message translates to:
  /// **'Premium'**
  String get subscriptionMenuRow;

  /// No description provided for @subscriptionMenuRowHint.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz mashq va to\'liq tahlil'**
  String get subscriptionMenuRowHint;

  /// No description provided for @subscriptionHomeCardTitle.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'ting'**
  String get subscriptionHomeCardTitle;

  /// No description provided for @subscriptionHomeCardBody.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz mashq, sun\'iy intellekt tahlili va PDF hisobotlar'**
  String get subscriptionHomeCardBody;

  /// No description provided for @planLimitTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bepul reja chegarasi'**
  String get planLimitTitle;

  /// No description provided for @planLimitMascotMessage.
  ///
  /// In uz, this message translates to:
  /// **'Premium bilan cheksiz mashq sizni kutmoqda!'**
  String get planLimitMascotMessage;

  /// No description provided for @planLimitExercisesBody.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi mashq chegarasiga yetib keldingiz. Premiumga o\'tib cheksiz mashq qiling.'**
  String get planLimitExercisesBody;

  /// No description provided for @planLimitAssessmentsBody.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi tahlil chegarasiga yetib keldingiz. Premiumga o\'tib cheksiz tahlil qiling.'**
  String get planLimitAssessmentsBody;

  /// No description provided for @planLimitAiBody.
  ///
  /// In uz, this message translates to:
  /// **'Sun\'iy intellekt tahlillari oylik chegarasiga yetib keldingiz. Premiumga o\'tib cheksiz tahlilni oching.'**
  String get planLimitAiBody;

  /// No description provided for @planLimitChildrenBody.
  ///
  /// In uz, this message translates to:
  /// **'Bola qo\'shish chegarasiga yetib keldingiz. Premiumga o\'tib 5 tagacha bola qo\'shing.'**
  String get planLimitChildrenBody;

  /// No description provided for @planLimitGenericBody.
  ///
  /// In uz, this message translates to:
  /// **'Bepul rejada bu amal cheklangan. Premiumga o\'tib barcha imkoniyatlarni oching.'**
  String get planLimitGenericBody;

  /// No description provided for @planLimitUpgradeCta.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tish'**
  String get planLimitUpgradeCta;

  /// No description provided for @planLimitDismiss.
  ///
  /// In uz, this message translates to:
  /// **'Hozir emas'**
  String get planLimitDismiss;

  /// No description provided for @subscriptionStatusTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mening obunam'**
  String get subscriptionStatusTitle;

  /// No description provided for @subscriptionStatusErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Obuna ma\'lumotlarini yuklab bo\'lmadi'**
  String get subscriptionStatusErrorTitle;

  /// No description provided for @subscriptionStatusErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get subscriptionStatusErrorBody;

  /// No description provided for @subscriptionStatusErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get subscriptionStatusErrorRetry;

  /// No description provided for @subscriptionStatusYourPlanLabel.
  ///
  /// In uz, this message translates to:
  /// **'Joriy reja'**
  String get subscriptionStatusYourPlanLabel;

  /// No description provided for @subscriptionStatusFreeHeroTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozir bepul rejadasiz'**
  String get subscriptionStatusFreeHeroTitle;

  /// No description provided for @subscriptionStatusFreeHeroBody.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tib cheksiz mashq, batafsil tahlil va shaxsiy tavsiyalarni oching.'**
  String get subscriptionStatusFreeHeroBody;

  /// No description provided for @subscriptionStatusFreeMascotMessage.
  ///
  /// In uz, this message translates to:
  /// **'Premium bilan bolangiz tezroq rivojlanadi!'**
  String get subscriptionStatusFreeMascotMessage;

  /// No description provided for @subscriptionStatusFreeBullet1.
  ///
  /// In uz, this message translates to:
  /// **'Bepul rejada bugungi mashqlar va asosiy tahlil mavjud.'**
  String get subscriptionStatusFreeBullet1;

  /// No description provided for @subscriptionStatusFreeBullet2.
  ///
  /// In uz, this message translates to:
  /// **'Premium reja cheksiz mashq, AI tahlil va PDF eksportni ochadi.'**
  String get subscriptionStatusFreeBullet2;

  /// No description provided for @subscriptionStatusFreeBullet3.
  ///
  /// In uz, this message translates to:
  /// **'Istalgan vaqtda bekor qilishingiz mumkin.'**
  String get subscriptionStatusFreeBullet3;

  /// No description provided for @subscriptionStatusUpgradeCta.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tish'**
  String get subscriptionStatusUpgradeCta;

  /// No description provided for @subscriptionStatusChangePlanCta.
  ///
  /// In uz, this message translates to:
  /// **'Rejani o\'zgartirish'**
  String get subscriptionStatusChangePlanCta;

  /// No description provided for @subscriptionStatusCancelCta.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilanishni o\'chirish'**
  String get subscriptionStatusCancelCta;

  /// No description provided for @subscriptionStatusActiveMascot.
  ///
  /// In uz, this message translates to:
  /// **'Premium imkoniyatlardan to\'liq foydalanmoqdasiz!'**
  String get subscriptionStatusActiveMascot;

  /// No description provided for @subscriptionStatusCancelledMascot.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilindi, lekin obuna muddati tugaguncha imkoniyatlar saqlanadi.'**
  String get subscriptionStatusCancelledMascot;

  /// No description provided for @subscriptionStatusExpiredMascot.
  ///
  /// In uz, this message translates to:
  /// **'Obuna muddati tugadi. Yangilashni xohlaysizmi?'**
  String get subscriptionStatusExpiredMascot;

  /// No description provided for @subscriptionStatusBadgeActive.
  ///
  /// In uz, this message translates to:
  /// **'Faol'**
  String get subscriptionStatusBadgeActive;

  /// No description provided for @subscriptionStatusBadgeCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get subscriptionStatusBadgeCancelled;

  /// No description provided for @subscriptionStatusBadgeExpired.
  ///
  /// In uz, this message translates to:
  /// **'Muddati tugagan'**
  String get subscriptionStatusBadgeExpired;

  /// No description provided for @subscriptionStatusBadgePastDue.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov kutilmoqda'**
  String get subscriptionStatusBadgePastDue;

  /// No description provided for @subscriptionStatusAutoRenewLabel.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilash'**
  String get subscriptionStatusAutoRenewLabel;

  /// No description provided for @subscriptionStatusAutoRenewOn.
  ///
  /// In uz, this message translates to:
  /// **'Yoqilgan'**
  String get subscriptionStatusAutoRenewOn;

  /// No description provided for @subscriptionStatusAutoRenewOff.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirilgan'**
  String get subscriptionStatusAutoRenewOff;

  /// No description provided for @subscriptionStatusStartedLabel.
  ///
  /// In uz, this message translates to:
  /// **'Boshlangan sana'**
  String get subscriptionStatusStartedLabel;

  /// No description provided for @subscriptionStatusExpiresLabel.
  ///
  /// In uz, this message translates to:
  /// **'Tugash sanasi'**
  String get subscriptionStatusExpiresLabel;

  /// No description provided for @subscriptionStatusDaysRemainingLabel.
  ///
  /// In uz, this message translates to:
  /// **'Qolgan kunlar'**
  String get subscriptionStatusDaysRemainingLabel;

  /// No description provided for @subscriptionStatusDaysRemainingValue.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Bugun tugaydi} =1{1 kun} other{{count} kun}}'**
  String subscriptionStatusDaysRemainingValue(int count);

  /// No description provided for @subscriptionStatusUnknown.
  ///
  /// In uz, this message translates to:
  /// **'—'**
  String get subscriptionStatusUnknown;

  /// No description provided for @subscriptionStatusFeaturesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Reja imkoniyatlari'**
  String get subscriptionStatusFeaturesTitle;

  /// No description provided for @subscriptionStatusExpiredHint.
  ///
  /// In uz, this message translates to:
  /// **'Obuna muddati tugadi. Cheksiz imkoniyatlardan qaytadan foydalanish uchun rejani yangilang.'**
  String get subscriptionStatusExpiredHint;

  /// No description provided for @subscriptionStatusCancelledHint.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilash o\'chirilgan. Imkoniyatlar {date}gacha saqlanadi.'**
  String subscriptionStatusCancelledHint(String date);

  /// No description provided for @subscriptionStatusCancelDialogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilashni o\'chirish?'**
  String get subscriptionStatusCancelDialogTitle;

  /// No description provided for @subscriptionStatusCancelDialogBody.
  ///
  /// In uz, this message translates to:
  /// **'Joriy davr tugaguncha barcha Premium imkoniyatlardan foydalanishda davom etasiz, keyin esa bepul rejaga qaytasiz.'**
  String get subscriptionStatusCancelDialogBody;

  /// No description provided for @subscriptionStatusCancelDialogKeep.
  ///
  /// In uz, this message translates to:
  /// **'Saqlab qolish'**
  String get subscriptionStatusCancelDialogKeep;

  /// No description provided for @subscriptionStatusCancelDialogConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Ha, o\'chirish'**
  String get subscriptionStatusCancelDialogConfirm;

  /// No description provided for @subscriptionStatusCancelSuccessSnack.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilash o\'chirildi. Joriy davr tugaguncha imkoniyatlar saqlanadi.'**
  String get subscriptionStatusCancelSuccessSnack;

  /// No description provided for @subscriptionStatusCancelFailedSnack.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilib bo\'lmadi. Iltimos, keyinroq qayta urinib ko\'ring.'**
  String get subscriptionStatusCancelFailedSnack;

  /// No description provided for @subscriptionStatusCancelComingSoonTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada!'**
  String get subscriptionStatusCancelComingSoonTitle;

  /// No description provided for @subscriptionStatusCancelComingSoonBody.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilashni boshqarish funksiyasi tez orada ishga tushadi. Yordam kerak bo\'lsa, biz bilan bog\'laning.'**
  String get subscriptionStatusCancelComingSoonBody;

  /// No description provided for @subscriptionStatusCancelComingSoonClose.
  ///
  /// In uz, this message translates to:
  /// **'Tushundim'**
  String get subscriptionStatusCancelComingSoonClose;

  /// No description provided for @subscriptionStatusResumeCta.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilashni qayta yoqish'**
  String get subscriptionStatusResumeCta;

  /// No description provided for @subscriptionStatusResumeDialogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Obunani davom ettirasizmi?'**
  String get subscriptionStatusResumeDialogTitle;

  /// No description provided for @subscriptionStatusResumeDialogBody.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilash qayta yoqiladi va keyingi davr boshlanganda obuna avtomatik uzaytiriladi.'**
  String get subscriptionStatusResumeDialogBody;

  /// No description provided for @subscriptionStatusResumeDialogKeep.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha kerak emas'**
  String get subscriptionStatusResumeDialogKeep;

  /// No description provided for @subscriptionStatusResumeDialogConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Ha, davom etish'**
  String get subscriptionStatusResumeDialogConfirm;

  /// No description provided for @subscriptionStatusResumeSuccessSnack.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik yangilash qayta yoqildi.'**
  String get subscriptionStatusResumeSuccessSnack;

  /// No description provided for @subscriptionStatusResumeFailedSnack.
  ///
  /// In uz, this message translates to:
  /// **'Davom ettirib bo\'lmadi. Iltimos, keyinroq qayta urinib ko\'ring.'**
  String get subscriptionStatusResumeFailedSnack;

  /// No description provided for @subscriptionStatusResumeComingSoonTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada!'**
  String get subscriptionStatusResumeComingSoonTitle;

  /// No description provided for @subscriptionStatusResumeComingSoonBody.
  ///
  /// In uz, this message translates to:
  /// **'Obunani qayta yoqish funksiyasi tez orada ishga tushadi. Yordam kerak bo\'lsa, biz bilan bog\'laning.'**
  String get subscriptionStatusResumeComingSoonBody;

  /// No description provided for @subscriptionStatusManageMenuRow.
  ///
  /// In uz, this message translates to:
  /// **'Obunani boshqarish'**
  String get subscriptionStatusManageMenuRow;

  /// No description provided for @subscriptionStatusManageMenuHint.
  ///
  /// In uz, this message translates to:
  /// **'Joriy reja, holat va to\'lovlar'**
  String get subscriptionStatusManageMenuHint;

  /// No description provided for @subscriptionUsageTitle.
  ///
  /// In uz, this message translates to:
  /// **'Joriy davr foydalanuvi'**
  String get subscriptionUsageTitle;

  /// No description provided for @subscriptionUsageSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bu davrda nimadan qancha foydalanganingizni kuzating.'**
  String get subscriptionUsageSubtitle;

  /// No description provided for @subscriptionUsageMascotMessage.
  ///
  /// In uz, this message translates to:
  /// **'Tez-tez mashq qilish — tezroq natija demakdir!'**
  String get subscriptionUsageMascotMessage;

  /// No description provided for @subscriptionUsageEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuv tez orada paydo bo\'ladi'**
  String get subscriptionUsageEmptyTitle;

  /// No description provided for @subscriptionUsageEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuv hisoboti hozir tayyorlanmoqda. Iltimos, keyinroq tekshiring.'**
  String get subscriptionUsageEmptyBody;

  /// No description provided for @subscriptionUsageErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvni yuklab bo\'lmadi'**
  String get subscriptionUsageErrorTitle;

  /// No description provided for @subscriptionUsageErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get subscriptionUsageErrorBody;

  /// No description provided for @subscriptionUsageErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get subscriptionUsageErrorRetry;

  /// No description provided for @subscriptionUsagePeriodLabel.
  ///
  /// In uz, this message translates to:
  /// **'Davr {start} – {end}'**
  String subscriptionUsagePeriodLabel(String start, String end);

  /// No description provided for @subscriptionUsageResetsAt.
  ///
  /// In uz, this message translates to:
  /// **'{date} da yangilanadi'**
  String subscriptionUsageResetsAt(String date);

  /// No description provided for @subscriptionUsageUnlimited.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz'**
  String get subscriptionUsageUnlimited;

  /// No description provided for @subscriptionUsageRemaining.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Limit tugadi} =1{1 ta qoldi} other{{count} ta qoldi}}'**
  String subscriptionUsageRemaining(int count);

  /// No description provided for @subscriptionUsageUsedOf.
  ///
  /// In uz, this message translates to:
  /// **'{used} / {limit}'**
  String subscriptionUsageUsedOf(int used, int limit);

  /// No description provided for @subscriptionUsageMetricAssessmentsPerDay.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik baholashlar'**
  String get subscriptionUsageMetricAssessmentsPerDay;

  /// No description provided for @subscriptionUsageMetricExercisesPerDay.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik mashqlar'**
  String get subscriptionUsageMetricExercisesPerDay;

  /// No description provided for @subscriptionUsageMetricAi.
  ///
  /// In uz, this message translates to:
  /// **'AI tahlillari'**
  String get subscriptionUsageMetricAi;

  /// No description provided for @subscriptionUsageMetricChildren.
  ///
  /// In uz, this message translates to:
  /// **'Bolalar profili'**
  String get subscriptionUsageMetricChildren;

  /// No description provided for @subscriptionUsageMetricRecordings.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvlar'**
  String get subscriptionUsageMetricRecordings;

  /// No description provided for @subscriptionUsageMetricPatients.
  ///
  /// In uz, this message translates to:
  /// **'Bemorlar'**
  String get subscriptionUsageMetricPatients;

  /// No description provided for @subscriptionUsageMetricUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuv'**
  String get subscriptionUsageMetricUnknown;

  /// No description provided for @subscriptionUsageExhaustedHint.
  ///
  /// In uz, this message translates to:
  /// **'Limitga yetdingiz. Davom etish uchun Premiumga o\'ting.'**
  String get subscriptionUsageExhaustedHint;

  /// No description provided for @subscriptionUsageUpgradeCta.
  ///
  /// In uz, this message translates to:
  /// **'Limitni oshirish'**
  String get subscriptionUsageUpgradeCta;

  /// No description provided for @homeUsageMeterTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi foydalanish'**
  String get homeUsageMeterTitle;

  /// No description provided for @homeUsageMeterSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bepul rejada bugun yana qancha mashq qila olasiz'**
  String get homeUsageMeterSubtitle;

  /// No description provided for @homeUsageMeterNearLimitTitle.
  ///
  /// In uz, this message translates to:
  /// **'Limitga yaqin qoldingiz'**
  String get homeUsageMeterNearLimitTitle;

  /// No description provided for @homeUsageMeterNearLimitBody.
  ///
  /// In uz, this message translates to:
  /// **'Yana bir-ikki marta urinib koring — yoki Premium bilan cheklovni olib tashlang.'**
  String get homeUsageMeterNearLimitBody;

  /// No description provided for @homeUsageMeterExhaustedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi limit tugadi'**
  String get homeUsageMeterExhaustedTitle;

  /// No description provided for @homeUsageMeterExhaustedBody.
  ///
  /// In uz, this message translates to:
  /// **'Premium bilan cheksiz mashq va tahlil qiling.'**
  String get homeUsageMeterExhaustedBody;

  /// No description provided for @homeUsageMeterCta.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'ting'**
  String get homeUsageMeterCta;

  /// No description provided for @homeUsageMeterTapHint.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil ko\'rish'**
  String get homeUsageMeterTapHint;

  /// No description provided for @subscriptionCheckoutMethodTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov usulini tanlang'**
  String get subscriptionCheckoutMethodTitle;

  /// No description provided for @subscriptionCheckoutMethodBody.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tish uchun to\'lov tizimini tanlang. Barcha to\'lovlar shifrlangan va xavfsiz.'**
  String get subscriptionCheckoutMethodBody;

  /// No description provided for @subscriptionCheckoutPaymeName.
  ///
  /// In uz, this message translates to:
  /// **'Payme'**
  String get subscriptionCheckoutPaymeName;

  /// No description provided for @subscriptionCheckoutPaymeTagline.
  ///
  /// In uz, this message translates to:
  /// **'Karta yoki balans orqali to\'lov'**
  String get subscriptionCheckoutPaymeTagline;

  /// No description provided for @subscriptionCheckoutClickName.
  ///
  /// In uz, this message translates to:
  /// **'Click'**
  String get subscriptionCheckoutClickName;

  /// No description provided for @subscriptionCheckoutClickTagline.
  ///
  /// In uz, this message translates to:
  /// **'Click ilovasi bilan tezkor to\'lov'**
  String get subscriptionCheckoutClickTagline;

  /// No description provided for @subscriptionCheckoutSelectedPlan.
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan reja: {plan}'**
  String subscriptionCheckoutSelectedPlan(String plan);

  /// No description provided for @subscriptionCheckoutPreparing.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov sahifasi tayyorlanmoqda…'**
  String get subscriptionCheckoutPreparing;

  /// No description provided for @subscriptionCheckoutReadyTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov havolasi tayyor'**
  String get subscriptionCheckoutReadyTitle;

  /// No description provided for @subscriptionCheckoutReadyBody.
  ///
  /// In uz, this message translates to:
  /// **'Quyidagi havolani brauzeringizda oching va to\'lovni yakunlang. Yopilgandan so\'ng obuna avtomatik faollashadi.'**
  String get subscriptionCheckoutReadyBody;

  /// Primary CTA on the checkout-ready sheet that hands the URL to the device browser via url_launcher.
  ///
  /// In uz, this message translates to:
  /// **'Brauzerda ochish'**
  String get subscriptionCheckoutOpenInBrowser;

  /// Snackbar shown when url_launcher fails — we automatically fall back to copying the URL so the user is never blocked.
  ///
  /// In uz, this message translates to:
  /// **'Brauzerni ocholmadik — havola buferga nusxalandi'**
  String get subscriptionCheckoutOpenFailed;

  /// No description provided for @subscriptionCheckoutCopyUrl.
  ///
  /// In uz, this message translates to:
  /// **'Havolani nusxalash'**
  String get subscriptionCheckoutCopyUrl;

  /// No description provided for @subscriptionCheckoutUrlCopied.
  ///
  /// In uz, this message translates to:
  /// **'Havola nusxalandi — brauzerda oching'**
  String get subscriptionCheckoutUrlCopied;

  /// No description provided for @subscriptionCheckoutErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni boshlab bo\'lmadi'**
  String get subscriptionCheckoutErrorTitle;

  /// No description provided for @subscriptionCheckoutErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get subscriptionCheckoutErrorBody;

  /// No description provided for @subscriptionCheckoutRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get subscriptionCheckoutRetry;

  /// No description provided for @subscriptionCheckoutClose.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get subscriptionCheckoutClose;

  /// No description provided for @subscriptionCheckoutSecureNote.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov Payme va Click orqali himoyalangan.'**
  String get subscriptionCheckoutSecureNote;

  /// No description provided for @subscriptionHistoryTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovlar tarixi'**
  String get subscriptionHistoryTitle;

  /// No description provided for @subscriptionHistoryMenuRow.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovlar tarixi'**
  String get subscriptionHistoryMenuRow;

  /// No description provided for @subscriptionHistoryMenuHint.
  ///
  /// In uz, this message translates to:
  /// **'Avvalgi to\'lovlar va kvitansiyalar'**
  String get subscriptionHistoryMenuHint;

  /// No description provided for @subscriptionHistoryEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hali to\'lovlar yo\'q'**
  String get subscriptionHistoryEmptyTitle;

  /// No description provided for @subscriptionHistoryEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tganingizdan keyin to\'lovlar shu yerda paydo bo\'ladi.'**
  String get subscriptionHistoryEmptyBody;

  /// No description provided for @subscriptionHistoryEmptyCta.
  ///
  /// In uz, this message translates to:
  /// **'Premiumni ko\'rish'**
  String get subscriptionHistoryEmptyCta;

  /// No description provided for @subscriptionHistoryErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tarixni yuklab bo\'lmadi'**
  String get subscriptionHistoryErrorTitle;

  /// No description provided for @subscriptionHistoryErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get subscriptionHistoryErrorBody;

  /// No description provided for @subscriptionHistoryErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get subscriptionHistoryErrorRetry;

  /// No description provided for @subscriptionHistorySectionLabel.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =1{1 ta to\'lov} other{{count} ta to\'lov}}'**
  String subscriptionHistorySectionLabel(int count);

  /// No description provided for @subscriptionHistoryAmountLabel.
  ///
  /// In uz, this message translates to:
  /// **'{amount} so\'m'**
  String subscriptionHistoryAmountLabel(String amount);

  /// No description provided for @subscriptionHistoryStatePaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan'**
  String get subscriptionHistoryStatePaid;

  /// No description provided for @subscriptionHistoryStatePending.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda'**
  String get subscriptionHistoryStatePending;

  /// No description provided for @subscriptionHistoryStateCreated.
  ///
  /// In uz, this message translates to:
  /// **'Boshlangan'**
  String get subscriptionHistoryStateCreated;

  /// No description provided for @subscriptionHistoryStateCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get subscriptionHistoryStateCancelled;

  /// No description provided for @subscriptionHistoryStateUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Noma\'lum'**
  String get subscriptionHistoryStateUnknown;

  /// No description provided for @subscriptionHistoryProviderPayme.
  ///
  /// In uz, this message translates to:
  /// **'Payme'**
  String get subscriptionHistoryProviderPayme;

  /// No description provided for @subscriptionHistoryProviderClick.
  ///
  /// In uz, this message translates to:
  /// **'Click'**
  String get subscriptionHistoryProviderClick;

  /// No description provided for @subscriptionHistoryProviderUnknown.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tizimi'**
  String get subscriptionHistoryProviderUnknown;

  /// No description provided for @subscriptionHistoryDateUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Sana noma\'lum'**
  String get subscriptionHistoryDateUnknown;

  /// No description provided for @subscriptionHistoryRefresh.
  ///
  /// In uz, this message translates to:
  /// **'Yangilash'**
  String get subscriptionHistoryRefresh;

  /// No description provided for @paymentOrderDetailTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tafsilotlari'**
  String get paymentOrderDetailTitle;

  /// No description provided for @paymentOrderDetailLoading.
  ///
  /// In uz, this message translates to:
  /// **'Tafsilotlar yuklanmoqda…'**
  String get paymentOrderDetailLoading;

  /// No description provided for @paymentOrderDetailErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani yuklab bo\'lmadi'**
  String get paymentOrderDetailErrorTitle;

  /// No description provided for @paymentOrderDetailErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get paymentOrderDetailErrorBody;

  /// No description provided for @paymentOrderDetailErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get paymentOrderDetailErrorRetry;

  /// No description provided for @paymentOrderDetailNotFoundTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma topilmadi'**
  String get paymentOrderDetailNotFoundTitle;

  /// No description provided for @paymentOrderDetailNotFoundBody.
  ///
  /// In uz, this message translates to:
  /// **'Bu to\'lov endi mavjud emas yoki sizniki emas.'**
  String get paymentOrderDetailNotFoundBody;

  /// No description provided for @paymentOrderDetailNotFoundCta.
  ///
  /// In uz, this message translates to:
  /// **'Tarixga qaytish'**
  String get paymentOrderDetailNotFoundCta;

  /// No description provided for @paymentOrderDetailHeaderPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov yakunlandi'**
  String get paymentOrderDetailHeaderPaid;

  /// No description provided for @paymentOrderDetailHeaderPending.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov kutilmoqda'**
  String get paymentOrderDetailHeaderPending;

  /// No description provided for @paymentOrderDetailHeaderCreated.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov boshlangan'**
  String get paymentOrderDetailHeaderCreated;

  /// No description provided for @paymentOrderDetailHeaderCancelled.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov bekor qilingan'**
  String get paymentOrderDetailHeaderCancelled;

  /// No description provided for @paymentOrderDetailHeaderUnknown.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tafsilotlari'**
  String get paymentOrderDetailHeaderUnknown;

  /// No description provided for @paymentOrderDetailAmountLabel.
  ///
  /// In uz, this message translates to:
  /// **'Summa'**
  String get paymentOrderDetailAmountLabel;

  /// No description provided for @paymentOrderDetailPlanLabel.
  ///
  /// In uz, this message translates to:
  /// **'Tarif'**
  String get paymentOrderDetailPlanLabel;

  /// No description provided for @paymentOrderDetailProviderLabel.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tizimi'**
  String get paymentOrderDetailProviderLabel;

  /// No description provided for @paymentOrderDetailStateLabel.
  ///
  /// In uz, this message translates to:
  /// **'Holat'**
  String get paymentOrderDetailStateLabel;

  /// No description provided for @paymentOrderDetailOrderIdLabel.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma raqami'**
  String get paymentOrderDetailOrderIdLabel;

  /// No description provided for @paymentOrderDetailCreatedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yaratilgan'**
  String get paymentOrderDetailCreatedAt;

  /// No description provided for @paymentOrderDetailPaidAt.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan'**
  String get paymentOrderDetailPaidAt;

  /// No description provided for @paymentOrderDetailCancelledAt.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get paymentOrderDetailCancelledAt;

  /// No description provided for @paymentOrderDetailUpdatedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yangilangan'**
  String get paymentOrderDetailUpdatedAt;

  /// No description provided for @paymentOrderDetailResumeCta.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni davom ettirish'**
  String get paymentOrderDetailResumeCta;

  /// No description provided for @paymentOrderDetailHistoryCta.
  ///
  /// In uz, this message translates to:
  /// **'Tarixga qaytish'**
  String get paymentOrderDetailHistoryCta;

  /// No description provided for @paymentOrderDetailCopyId.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma raqami nusxalandi'**
  String get paymentOrderDetailCopyId;

  /// No description provided for @paymentOrderDetailReceiptHint.
  ///
  /// In uz, this message translates to:
  /// **'Kvitansiya tez orada elektron pochtangizga yuboriladi.'**
  String get paymentOrderDetailReceiptHint;

  /// No description provided for @paymentOrderDetailPendingHint.
  ///
  /// In uz, this message translates to:
  /// **'Agar to\'lov tasdiqlanmagan bo\'lsa, uni davom ettirishingiz mumkin.'**
  String get paymentOrderDetailPendingHint;

  /// No description provided for @paymentOrderDetailCancelledHint.
  ///
  /// In uz, this message translates to:
  /// **'Bu buyurtma bekor qilingan. Premiumga qayta o\'tish uchun yangi to\'lov yarating.'**
  String get paymentOrderDetailCancelledHint;

  /// No description provided for @paymentOrderDetailUnknownHint.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma holati noma\'lum. Qisqa vaqtdan so\'ng qayta urinib ko\'ring.'**
  String get paymentOrderDetailUnknownHint;

  /// No description provided for @planCompareTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rejalarni taqqoslash'**
  String get planCompareTitle;

  /// No description provided for @planCompareMenuRow.
  ///
  /// In uz, this message translates to:
  /// **'Rejalarni taqqoslash'**
  String get planCompareMenuRow;

  /// No description provided for @planCompareSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bepul, Premium va Logoped rejalarining imkoniyatlarini yonma-yon ko\'ring.'**
  String get planCompareSubtitle;

  /// No description provided for @planCompareMascotMessage.
  ///
  /// In uz, this message translates to:
  /// **'Sizga eng mos rejani tanlash uchun bir varaqda ko\'ring!'**
  String get planCompareMascotMessage;

  /// No description provided for @planCompareLoadingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Taqqoslash yuklanmoqda…'**
  String get planCompareLoadingTitle;

  /// No description provided for @planCompareErrorTitle.
  ///
  /// In uz, this message translates to:
  /// **'Taqqoslashni yuklab bo\'lmadi'**
  String get planCompareErrorTitle;

  /// No description provided for @planCompareErrorBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshirib, qayta urinib ko\'ring.'**
  String get planCompareErrorBody;

  /// No description provided for @planCompareErrorRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get planCompareErrorRetry;

  /// No description provided for @planCompareEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha rejalar yo\'q'**
  String get planCompareEmptyTitle;

  /// No description provided for @planCompareEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada yangi tariflar qo\'shiladi.'**
  String get planCompareEmptyBody;

  /// No description provided for @planCompareSectionUsage.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish chegaralari'**
  String get planCompareSectionUsage;

  /// No description provided for @planCompareSectionFeatures.
  ///
  /// In uz, this message translates to:
  /// **'Imkoniyatlar'**
  String get planCompareSectionFeatures;

  /// No description provided for @planCompareSectionSupport.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'llab-quvvatlash'**
  String get planCompareSectionSupport;

  /// No description provided for @planCompareRowExercises.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik mashqlar'**
  String get planCompareRowExercises;

  /// No description provided for @planCompareRowAssessments.
  ///
  /// In uz, this message translates to:
  /// **'Kunlik baholashlar'**
  String get planCompareRowAssessments;

  /// No description provided for @planCompareRowAi.
  ///
  /// In uz, this message translates to:
  /// **'AI tahlillari'**
  String get planCompareRowAi;

  /// No description provided for @planCompareRowChildren.
  ///
  /// In uz, this message translates to:
  /// **'Bola profillari'**
  String get planCompareRowChildren;

  /// No description provided for @planCompareRowPatients.
  ///
  /// In uz, this message translates to:
  /// **'Bemor profillari'**
  String get planCompareRowPatients;

  /// No description provided for @planCompareRowDetailedProgress.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil taraqqiyot'**
  String get planCompareRowDetailedProgress;

  /// No description provided for @planCompareRowRecommendations.
  ///
  /// In uz, this message translates to:
  /// **'Shaxsiy tavsiyalar'**
  String get planCompareRowRecommendations;

  /// No description provided for @planCompareRowExportPdf.
  ///
  /// In uz, this message translates to:
  /// **'PDF eksport'**
  String get planCompareRowExportPdf;

  /// No description provided for @planCompareRowPatientManagement.
  ///
  /// In uz, this message translates to:
  /// **'Bemorlarni boshqarish'**
  String get planCompareRowPatientManagement;

  /// No description provided for @planCompareRowAssignExercises.
  ///
  /// In uz, this message translates to:
  /// **'Mashq biriktirish'**
  String get planCompareRowAssignExercises;

  /// No description provided for @planCompareRowTherapyGoals.
  ///
  /// In uz, this message translates to:
  /// **'Davolash maqsadlari'**
  String get planCompareRowTherapyGoals;

  /// No description provided for @planCompareRowScreeningBattery.
  ///
  /// In uz, this message translates to:
  /// **'Skrining to\'plami'**
  String get planCompareRowScreeningBattery;

  /// No description provided for @planCompareRowReferralPdf.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'llanma (PDF)'**
  String get planCompareRowReferralPdf;

  /// No description provided for @planCompareRowAnalytics.
  ///
  /// In uz, this message translates to:
  /// **'Analitika'**
  String get planCompareRowAnalytics;

  /// No description provided for @planCompareRowPrioritySupport.
  ///
  /// In uz, this message translates to:
  /// **'Ustuvor yordam'**
  String get planCompareRowPrioritySupport;

  /// No description provided for @planCompareCellUnlimited.
  ///
  /// In uz, this message translates to:
  /// **'Cheksiz'**
  String get planCompareCellUnlimited;

  /// No description provided for @planCompareCellPerDay.
  ///
  /// In uz, this message translates to:
  /// **'{count}/kun'**
  String planCompareCellPerDay(int count);

  /// No description provided for @planCompareCellPerMonth.
  ///
  /// In uz, this message translates to:
  /// **'{count}/oy'**
  String planCompareCellPerMonth(int count);

  /// No description provided for @planCompareCellCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta'**
  String planCompareCellCount(int count);

  /// No description provided for @planCompareCellIncluded.
  ///
  /// In uz, this message translates to:
  /// **'Mavjud'**
  String get planCompareCellIncluded;

  /// No description provided for @planCompareCellExcluded.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q'**
  String get planCompareCellExcluded;

  /// No description provided for @planCompareCellEmail.
  ///
  /// In uz, this message translates to:
  /// **'Elektron pochta'**
  String get planCompareCellEmail;

  /// No description provided for @planCompareCellPriority.
  ///
  /// In uz, this message translates to:
  /// **'Ustuvor'**
  String get planCompareCellPriority;

  /// No description provided for @planCompareCurrentBadge.
  ///
  /// In uz, this message translates to:
  /// **'Joriy'**
  String get planCompareCurrentBadge;

  /// No description provided for @planCompareRecommendedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya'**
  String get planCompareRecommendedBadge;

  /// No description provided for @planCompareCtaUpgrade.
  ///
  /// In uz, this message translates to:
  /// **'Premiumga o\'tish'**
  String get planCompareCtaUpgrade;

  /// No description provided for @planCompareCtaCurrent.
  ///
  /// In uz, this message translates to:
  /// **'Joriy reja'**
  String get planCompareCtaCurrent;

  /// No description provided for @planCompareCtaContact.
  ///
  /// In uz, this message translates to:
  /// **'Logoped uchun bog\'lanish'**
  String get planCompareCtaContact;

  /// No description provided for @planCompareEntryCta.
  ///
  /// In uz, this message translates to:
  /// **'Rejalarni taqqoslash'**
  String get planCompareEntryCta;

  /// No description provided for @planCompareEntryHint.
  ///
  /// In uz, this message translates to:
  /// **'Imkoniyatlarni yonma-yon ko\'ring'**
  String get planCompareEntryHint;

  /// No description provided for @planCompareSemanticsRow.
  ///
  /// In uz, this message translates to:
  /// **'{feature}: {free} bepul, {pro} premium, {logoped} logoped'**
  String planCompareSemanticsRow(
    String feature,
    String free,
    String pro,
    String logoped,
  );
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return LRu();
    case 'uz':
      return LUz();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
