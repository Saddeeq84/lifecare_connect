import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

extension CarryGoLocalizations on BuildContext {
  String tr(String text) {
    final code = watch<SettingsProvider>().languageCode;
    return AppTranslations.translate(text, code);
  }

  String trRead(String text) {
    final code = read<SettingsProvider>().languageCode;
    return AppTranslations.translate(text, code);
  }
}

class AppTranslations {
  static String translate(String text, String code) {
    if (code == 'en') return text;
    return _values[text]?[code] ?? text;
  }

  static const Map<String, Map<String, String>> _values = {
    'CarryGo': {'ha': 'CarryGo', 'ig': 'CarryGo', 'yo': 'CarryGo'},
    'Customer': {'ha': 'Abokin ciniki', 'ig': 'Onye ahịa', 'yo': 'Onibara'},
    'Rider': {'ha': 'Mai keke', 'ig': 'Onye rider', 'yo': 'Rider'},
    'Admin': {'ha': 'Mai gudanarwa', 'ig': 'Onye nchịkwa', 'yo': 'Alabojuto'},
    'Settings': {'ha': 'Saituna', 'ig': 'Ntọala', 'yo': 'Eto'},
    'App settings': {
      'ha': 'Saitunan app',
      'ig': 'Ntọala ngwa',
      'yo': 'Eto app'
    },
    'Language': {'ha': 'Harshe', 'ig': 'Asụsụ', 'yo': 'Ede'},
    'English': {'ha': 'Turanci', 'ig': 'Bekee', 'yo': 'Gẹẹsi'},
    'Hausa': {'ha': 'Hausa', 'ig': 'Hausa', 'yo': 'Hausa'},
    'Igbo': {'ha': 'Igbo', 'ig': 'Igbo', 'yo': 'Igbo'},
    'Yoruba': {'ha': 'Yarbanci', 'ig': 'Yoruba', 'yo': 'Yoruba'},
    'Choose app language': {
      'ha': 'Zaɓi harshen app',
      'ig': 'Họrọ asụsụ ngwa',
      'yo': 'Yan ede app'
    },
    'Changes apply instantly across the app.': {
      'ha': 'Canje-canje suna aiki nan take a duk app.',
      'ig': 'Mgbanwe na-arụ ọrụ ozugbo n’ime ngwa niile.',
      'yo': 'Ayipada yoo ṣiṣẹ lẹsẹkẹsẹ ninu app.'
    },
    'Account': {'ha': 'Asusu', 'ig': 'Akaụntụ', 'yo': 'Akaunti'},
    'Manage profile and login details': {
      'ha': 'Sarrafa bayanan martaba da shiga',
      'ig': 'Jikwaa profaịlụ na nkọwa nbanye',
      'yo': 'Ṣakoso profaili ati alaye wiwọle'
    },
    'Notifications': {'ha': 'Sanarwa', 'ig': 'Ọkwa', 'yo': 'Iwifunni'},
    'Booking alerts, SMS and in-app messages': {
      'ha': 'Faɗakarwar booking, SMS da saƙonnin cikin app',
      'ig': 'Ọkwa booking, SMS na ozi n’ime ngwa',
      'yo': 'Itaniji booking, SMS ati ifiranṣẹ inu app'
    },
    'Payments and wallet': {
      'ha': 'Biya da wallet',
      'ig': 'Ịkwụ ụgwọ na wallet',
      'yo': 'Isanwo ati wallet'
    },
    'Cards, cash, escrow and withdrawals': {
      'ha': 'Kati, cash, escrow da cire kuɗi',
      'ig': 'Kaadị, ego aka, escrow na iwepụ ego',
      'yo': 'Kaadi, owo, escrow ati yiyọ owo'
    },
    'Privacy and security': {
      'ha': 'Sirri da tsaro',
      'ig': 'Nzuzo na nchekwa',
      'yo': 'Asiri ati aabo'
    },
    'Password, OTP and account safety': {
      'ha': 'Kalmar sirri, OTP da tsaron asusu',
      'ig': 'Paswọọdụ, OTP na nchekwa akaụntụ',
      'yo': 'Ọrọigbaniwọle, OTP ati aabo akaunti'
    },
    'Help and support': {'ha': 'Taimako', 'ig': 'Enyemaka', 'yo': 'Iranlọwọ'},
    'Complaints, disputes and customer care': {
      'ha': 'Korafe-korafe, rikici da kula da abokin ciniki',
      'ig': 'Mkpesa, esemokwu na nlekọta ndị ahịa',
      'yo': 'Ẹdun, ariyanjiyan ati itoju onibara'
    },
    'App version': {'ha': 'Sigar app', 'ig': 'Ụdị ngwa', 'yo': 'Ẹya app'},
    'Production MVP': {
      'ha': 'MVP na samarwa',
      'ig': 'MVP mmepụta',
      'yo': 'MVP iṣelọpọ'
    },
    'Log out': {'ha': 'Fita', 'ig': 'Pụọ', 'yo': 'Jade'},
    'Sign in to continue.': {
      'ha': 'Shiga don ci gaba.',
      'ig': 'Banye ka ịga n’ihu.',
      'yo': 'Wọle lati tẹsiwaju.'
    },
    'New request': {
      'ha': 'Sabon buƙata',
      'ig': 'Arịrịọ ọhụrụ',
      'yo': 'Ibere tuntun'
    },
    'We carry. You relax.': {
      'ha': 'Mu ne ke kaiwa. Ka huta.',
      'ig': 'Anyị na-ebuga. Ị zuru ike.',
      'yo': 'A gbe e. Iwọ sinmi.'
    },
    'Email or phone number': {
      'ha': 'Imel ko lambar waya',
      'ig': 'Email ma ọ bụ nọmba ekwentị',
      'yo': 'Imeeli tabi nọmba foonu'
    },
    'Password': {'ha': 'Kalmar sirri', 'ig': 'Paswọọdụ', 'yo': 'Ọrọigbaniwọle'},
    'Login': {'ha': 'Shiga', 'ig': 'Banye', 'yo': 'Wọle'},
    'Logging in...': {
      'ha': 'Ana shiga...',
      'ig': 'Na-abanye...',
      'yo': 'N wọle...'
    },
    'Create account': {
      'ha': 'Ƙirƙiri asusu',
      'ig': 'Mepụta akaụntụ',
      'yo': 'Ṣẹda akaunti'
    },
    'Forgot password?': {
      'ha': 'Ka manta kalmar sirri?',
      'ig': 'Chefuru paswọọdụ?',
      'yo': 'Gbagbe ọrọigbaniwọle?'
    },
    'Dashboard': {'ha': 'Dashboard', 'ig': 'Dashboard', 'yo': 'Dashboard'},
    'CarryGo dashboard': {
      'ha': 'Dashboard na CarryGo',
      'ig': 'Dashboard CarryGo',
      'yo': 'Dashboard CarryGo'
    },
    'Book errands, track riders, and manage payments.': {
      'ha': 'Yi booking, bibiyi riders, kuma sarrafa biyan kuɗi.',
      'ig': 'Kwụpụta errands, soro riders, jikwaa ịkwụ ụgwọ.',
      'yo': 'Book errands, tọpa riders, ki o ṣakoso isanwo.'
    },
    'Book': {'ha': 'Yi booking', 'ig': 'Book', 'yo': 'Book'},
    'Active': {'ha': 'Masu aiki', 'ig': 'Na-arụ ọrụ', 'yo': 'Ti n ṣiṣẹ'},
    'Completed': {'ha': 'An kammala', 'ig': 'Emechara', 'yo': 'Ti pari'},
    'Wallet': {'ha': 'Wallet', 'ig': 'Wallet', 'yo': 'Wallet'},
    'Rider wallet': {
      'ha': 'Wallet na rider',
      'ig': 'Wallet rider',
      'yo': 'Wallet rider'
    },
    'Available for withdrawal': {
      'ha': 'Akwai don cirewa',
      'ig': 'Dị maka iwepụ',
      'yo': 'Wa fun yiyọ'
    },
    'Withdraw': {'ha': 'Cire kuɗi', 'ig': 'Wepụ ego', 'yo': 'Yọ owo'},
    'Withdrawal request will be sent to admin for processing.': {
      'ha': 'Za a aika buƙatar cire kuɗi ga admin don aiki.',
      'ig': 'A ga-eziga arịrịọ iwepụ ego n’aka admin maka nhazi.',
      'yo': 'A o fi ibeere yiyọ owo ranṣẹ si admin fun sise.'
    },
    'Earnings history': {
      'ha': 'Tarihin samun kuɗi',
      'ig': 'Akụkọ ego enwetara',
      'yo': 'Itan owo ti a gba'
    },
    'No rider earnings yet': {
      'ha': 'Babu samun kuɗin rider tukuna',
      'ig': 'Enweghị ego rider ka ọ dị',
      'yo': 'Ko si owo rider sibẹ'
    },
    'Order': {'ha': 'Oda', 'ig': 'Iwu', 'yo': 'Oda'},
    'Status': {'ha': 'Matsayi', 'ig': 'Ọnọdụ', 'yo': 'Ipo'},
    'Verification': {'ha': 'Tabbatarwa', 'ig': 'Nkwenye', 'yo': 'Ijẹrisi'},
    'Bike details': {
      'ha': 'Bayanan keke',
      'ig': 'Nkọwa bike',
      'yo': 'Alaye bike'
    },
    'Bank account': {
      'ha': 'Asusun banki',
      'ig': 'Akaụntụ bank',
      'yo': 'Akaunti banki'
    },
    'Customer bookings appear here when payment is ready or cash collection is selected.':
        {
      'ha':
          'Booking na customers zai bayyana nan idan biya ya shirya ko an zaɓi karɓar cash.',
      'ig':
          'Booking ndị customer ga-apụta ebe a mgbe ịkwụ ụgwọ dị njikere ma ọ bụ họrọ cash.',
      'yo':
          'Booking awon customer yoo han nibi nigbati isanwo ba setan tabi ti yan gbigba cash.'
    },
    'Escrow enabled': {
      'ha': 'Escrow yana aiki',
      'ig': 'Escrow dị',
      'yo': 'Escrow wa'
    },
    'Recent requests': {
      'ha': 'Buƙatu na baya-bayan nan',
      'ig': 'Arịrịọ ọhụrụ gara aga',
      'yo': 'Awọn ibere aipẹ'
    },
    'No deliveries yet': {
      'ha': 'Babu delivery tukuna',
      'ig': 'Enweghị mbufe ka ọ dị',
      'yo': 'Ko si ifijiṣẹ sibẹ'
    },
    'Route': {'ha': 'Hanya', 'ig': 'Ụzọ', 'yo': 'Ọna'},
    'Payment': {'ha': 'Biyan kuɗi', 'ig': 'Ịkwụ ụgwọ', 'yo': 'Isanwo'},
    'Pay with Paystack': {
      'ha': 'Biya da Paystack',
      'ig': 'Kwụọ na Paystack',
      'yo': 'Sanwo pẹlu Paystack'
    },
    'Dispute/refund': {
      'ha': 'Rikici/mayar da kuɗi',
      'ig': 'Esemokwu/nkwụghachi',
      'yo': 'Ariyànjiyàn/idapada'
    },
    'Call rider': {'ha': 'Kira rider', 'ig': 'Kpọọ rider', 'yo': 'Pe rider'},
    'WhatsApp': {'ha': 'WhatsApp', 'ig': 'WhatsApp', 'yo': 'WhatsApp'},
    'View route': {'ha': 'Duba hanya', 'ig': 'Lee ụzọ', 'yo': 'Wo ọna'},
    'Rate delivery': {
      'ha': 'Ba delivery rating',
      'ig': 'Nye mbufe rating',
      'yo': 'Ṣe rating ifijiṣẹ'
    },
    'Accept time': {
      'ha': 'Amince lokaci',
      'ig': 'Nabata oge',
      'yo': 'Gba akoko'
    },
    'Reject and cancel': {
      'ha': 'Ƙi kuma soke',
      'ig': 'Jụ ma kagbuo',
      'yo': 'Kọ ki o fagile'
    },
    'Rider accepted': {
      'ha': 'Rider ya amince',
      'ig': 'Rider anabatala',
      'yo': 'Rider ti gba'
    },
    'Picked up': {'ha': 'An ɗauka', 'ig': 'Eburu ya', 'yo': 'Ti gbe'},
    'In transit': {'ha': 'Yana hanya', 'ig': 'Na njem', 'yo': 'Lori ọna'},
    'Delivered': {'ha': 'An kai', 'ig': 'Ebugara', 'yo': 'Ti jiṣẹ'},
    'Cancelled': {'ha': 'An soke', 'ig': 'A kagbuola', 'yo': 'Ti fagile'},
    'Online': {'ha': 'A kan layi', 'ig': 'N’ịntanetị', 'yo': 'Online'},
    'Offline': {'ha': 'Ba a kan layi', 'ig': 'Offline', 'yo': 'Offline'},
    'Active requests': {
      'ha': 'Buƙatu masu aiki',
      'ig': 'Arịrịọ na-arụ ọrụ',
      'yo': 'Awọn ibere ti n ṣiṣẹ'
    },
    'Completed jobs': {
      'ha': 'Ayyukan da aka kammala',
      'ig': 'Ọrụ emechara',
      'yo': 'Awọn iṣẹ ti pari'
    },
    'No active CarryGo requests': {
      'ha': 'Babu buƙatar CarryGo mai aiki',
      'ig': 'Enweghị arịrịọ CarryGo na-arụ ọrụ',
      'yo': 'Ko si ibere CarryGo to n ṣiṣẹ'
    },
    'Turn on availability to receive nearby requests.': {
      'ha': 'Kunna samuwa don karɓar buƙatu kusa.',
      'ig': 'Gbanye ịdị njikere iji nata arịrịọ dị nso.',
      'yo': 'Tan wiwa lati gba awọn ibere to sunmọ.'
    },
    'You are offline': {
      'ha': 'Ba ka kan layi',
      'ig': 'Ị nọ offline',
      'yo': 'O wa offline'
    },
    'Login failed': {
      'ha': 'Shiga ya kasa',
      'ig': 'Nbanye dara',
      'yo': 'Wiwọle kuna'
    },
    'Reset failed': {
      'ha': 'Sake saiti ya kasa',
      'ig': 'Reset dara',
      'yo': 'Atunto kuna'
    },
    'Enter your email address first.': {
      'ha': 'Da farko shigar da imel ɗinka.',
      'ig': 'Buru ụzọ tinye email gị.',
      'yo': 'Kọkọ tẹ imeeli rẹ sii.'
    },
    'Password reset is available for email accounts.': {
      'ha': 'Sake saita kalmar sirri yana aiki ne ga asusun imel.',
      'ig': 'Reset paswọọdụ dị maka akaụntụ email.',
      'yo': 'Atunto ọrọigbaniwọle wa fun akaunti imeeli.'
    },
    'Password reset link sent.': {
      'ha': 'An aika hanyar sake saita kalmar sirri.',
      'ig': 'E zigara njikọ reset paswọọdụ.',
      'yo': 'A ti fi ọna asopọ atunto ranṣẹ.'
    },
    'Full name': {
      'ha': 'Cikakken suna',
      'ig': 'Aha zuru ezu',
      'yo': 'Orukọ kikun'
    },
    'Contact phone number': {
      'ha': 'Lambar waya',
      'ig': 'Nọmba ekwentị',
      'yo': 'Nọmba foonu'
    },
    'Role': {'ha': 'Matsayi', 'ig': 'Ọrụ', 'yo': 'Ipa'},
    'City': {'ha': 'Birni', 'ig': 'Obodo', 'yo': 'Ilu'},
    'Creating...': {
      'ha': 'Ana ƙirƙira...',
      'ig': 'Na-emepụta...',
      'yo': 'N ṣẹda...'
    },
    'We could not create your account. Please try again.': {
      'ha': 'Ba mu iya ƙirƙirar asusunka ba. Da fatan a sake gwadawa.',
      'ig': 'Anyị enweghị ike ịmepụta akaụntụ gị. Biko nwaa ọzọ.',
      'yo': 'A ko le ṣẹda akaunti rẹ. Jọwọ gbiyanju lẹẹkansi.'
    },
    'Rider onboarding: submit your bike details and verification documents. An admin must approve you before jobs appear.':
        {
      'ha':
          'Rajistar rider: aika bayanan keke da takardun tantancewa. Admin zai amince kafin aiki ya bayyana.',
      'ig':
          'Mbanye rider: tinye nkọwa bike na akwụkwọ nkwenye. Admin ga-akwado tupu ọrụ apụta.',
      'yo':
          'Iforukọsilẹ rider: fi alaye bike ati iwe idaniloju silẹ. Admin gbọdọ fọwọsi ṣaaju ki iṣẹ han.'
    },
    'Customer onboarding: create an account, request errands, pay with Paystack, and track your rider to drop-off.':
        {
      'ha':
          'Rajistar abokin ciniki: ƙirƙiri asusu, nemi errand, biya da Paystack, kuma bi rider har zuwa drop-off.',
      'ig':
          'Mbanye onye ahịa: mepụta akaụntụ, rịọ errand, kwụọ na Paystack, soro rider ruo drop-off.',
      'yo':
          'Iforukọsilẹ onibara: ṣẹda akaunti, beere errand, sanwo pẹlu Paystack, ki o tọpa rider si drop-off.'
    },
    'Profile photo link': {
      'ha': 'Link hoton profile',
      'ig': 'Njikọ foto profaịlụ',
      'yo': 'Ọna asopọ fọto profaili'
    },
    'ID card link': {
      'ha': 'Link katin ID',
      'ig': 'Njikọ kaadị ID',
      'yo': 'Ọna asopọ kaadi ID'
    },
    'Bike plate number': {
      'ha': 'Lambar plate keke',
      'ig': 'Nọmba plate bike',
      'yo': 'Nọmba plate bike'
    },
    'Bike make/model': {
      'ha': 'Nau’in keke',
      'ig': 'Ụdị bike',
      'yo': 'Iru bike'
    },
    'Bike color': {'ha': 'Launin keke', 'ig': 'Agba bike', 'yo': 'Awọ bike'},
    'Bank name': {'ha': 'Sunan banki', 'ig': 'Aha bank', 'yo': 'Orukọ banki'},
    'Bank account number': {
      'ha': 'Lambar asusun banki',
      'ig': 'Nọmba akaụntụ bank',
      'yo': 'Nọmba akaunti banki'
    },
    'Bank account name': {
      'ha': 'Sunan asusun banki',
      'ig': 'Aha akaụntụ bank',
      'yo': 'Orukọ akaunti banki'
    },
    'Pick-up address or landmark': {
      'ha': 'Adireshin ɗauka ko alama',
      'ig': 'Adreesị iburu ma ọ bụ akara ebe',
      'yo': 'Adirẹsi gbigbe tabi ami ibi'
    },
    'Drop-off address or landmark': {
      'ha': 'Adireshin sauke ko alama',
      'ig': 'Adreesị idobe ma ọ bụ akara ebe',
      'yo': 'Adirẹsi ibi gbigbe de tabi ami ibi'
    },
    'Use current GPS for pick-up': {
      'ha': 'Yi amfani da GPS yanzu don ɗauka',
      'ig': 'Jiri GPS ugbu a maka iburu',
      'yo': 'Lo GPS lọwọlọwọ fun gbigbe'
    },
    'Search or move pick-up pin on map': {
      'ha': 'Nema ko matsar da pin ɗauka a taswira',
      'ig': 'Chọọ ma ọ bụ bugharịa pin iburu na map',
      'yo': 'Wa tabi gbe pin gbigbe lori maapu'
    },
    'Search or move drop-off pin on map': {
      'ha': 'Nema ko matsar da pin sauke a taswira',
      'ig': 'Chọọ ma ọ bụ bugharịa pin idobe na map',
      'yo': 'Wa tabi gbe pin ibi de lori maapu'
    },
    'Contacts': {'ha': 'Lambobi', 'ig': 'Kọntaktị', 'yo': 'Awọn olubasọrọ'},
    'Parcel': {'ha': 'Kaya', 'ig': 'Ngwugwu', 'yo': 'Ẹru'},
    'Sender name': {
      'ha': 'Sunan mai aikawa',
      'ig': 'Aha onye zipụrụ',
      'yo': 'Orukọ oluranṣẹ'
    },
    'Sender phone': {
      'ha': 'Wayar mai aikawa',
      'ig': 'Ekwentị onye zipụrụ',
      'yo': 'Foonu oluranṣẹ'
    },
    'Receiver name': {
      'ha': 'Sunan mai karɓa',
      'ig': 'Aha onye nata',
      'yo': 'Orukọ olugba'
    },
    'Receiver phone': {
      'ha': 'Wayar mai karɓa',
      'ig': 'Ekwentị onye nata',
      'yo': 'Foonu olugba'
    },
    'Item type': {'ha': 'Nau’in kaya', 'ig': 'Ụdị ihe', 'yo': 'Iru nkan'},
    'Parcel description': {
      'ha': 'Bayanin kaya',
      'ig': 'Nkọwa ngwugwu',
      'yo': 'Apejuwe ẹru'
    },
    'Parcel size': {'ha': 'Girman kaya', 'ig': 'Ogo ngwugwu', 'yo': 'Iwọn ẹru'},
    'Weight feel': {
      'ha': 'Nauyin da ake ji',
      'ig': 'Ibu a na-eche',
      'yo': 'Bi iwuwo ṣe ri'
    },
    'Fragility': {
      'ha': 'Sauƙin karyewa',
      'ig': 'Mmebi mfe',
      'yo': 'Rọrun lati bajẹ'
    },
    'Urgency': {'ha': 'Gaggawa', 'ig': 'Ọsọ mkpa', 'yo': 'Iyara'},
    'Weather/traffic condition': {
      'ha': 'Yanayi/cunkoso',
      'ig': 'Ihu igwe/traffic',
      'yo': 'Oju ojo/traffic'
    },
    'Estimate delivery cost': {
      'ha': 'Kiyasta kuɗin delivery',
      'ig': 'Tụọ ego mbufe',
      'yo': 'Ṣe iṣiro owo ifijiṣẹ'
    },
    'Create and pay by card': {
      'ha': 'Ƙirƙira ka biya da kati',
      'ig': 'Mepụta ma kwụọ na kaadị',
      'yo': 'Ṣẹda ki o sanwo pẹlu kaadi'
    },
    'Book rider': {
      'ha': 'Yi booking rider',
      'ig': 'Book rider',
      'yo': 'Book rider'
    },
    'Card': {'ha': 'Kati', 'ig': 'Kaadị', 'yo': 'Kaadi'},
    'Cash': {'ha': 'Cash', 'ig': 'Ego aka', 'yo': 'Owo'},
    'Card payment': {
      'ha': 'Biyan kati',
      'ig': 'Ịkwụ kaadị',
      'yo': 'Isanwo kaadi'
    },
    'Pay later': {
      'ha': 'Biya daga baya',
      'ig': 'Kwụọ mgbe e mesịrị',
      'yo': 'Sanwo nigbamii'
    },
    'Reference': {'ha': 'Lambar tunani', 'ig': 'Reference', 'yo': 'Reference'},
    'Amount': {'ha': 'Adadi', 'ig': 'Ego', 'yo': 'Iye'},
    'Cancel': {'ha': 'Soke', 'ig': 'Kagbuo', 'yo': 'Fagile'},
    'Submit': {'ha': 'Aika', 'ig': 'Ziga', 'yo': 'Fi silẹ'},
    'Confirm': {'ha': 'Tabbatar', 'ig': 'Kwenye', 'yo': 'Jẹrisi'},
    'Close': {'ha': 'Rufe', 'ig': 'Mechie', 'yo': 'Pa'},
    'Reject': {'ha': 'Ƙi', 'ig': 'Jụ', 'yo': 'Kọ'},
    'Propose time': {
      'ha': 'Ba da sabon lokaci',
      'ig': 'Tụpụta oge',
      'yo': 'Dabaa akoko'
    },
    'Confirm pick-up': {
      'ha': 'Tabbatar ɗauka',
      'ig': 'Kwenye iburu',
      'yo': 'Jẹrisi gbigbe'
    },
    'Navigate to drop-off': {
      'ha': 'Je zuwa wurin sauke',
      'ig': 'Gaa ebe idobe',
      'yo': 'Lilö si ibi de'
    },
    'Navigate to pick-up': {
      'ha': 'Je zuwa wurin ɗauka',
      'ig': 'Gaa ebe iburu',
      'yo': 'Lilö si ibi gbigbe'
    },
    'Confirm delivery OTP': {
      'ha': 'Tabbatar OTP delivery',
      'ig': 'Kwenye OTP mbufe',
      'yo': 'Jẹrisi OTP ifijiṣẹ'
    },
    'Contact': {'ha': 'Tuntuɓi', 'ig': 'Kpọtụrụ', 'yo': 'Kan si'},
    'Contact rider': {
      'ha': 'Tuntuɓi rider',
      'ig': 'Kpọtụrụ rider',
      'yo': 'Kan si rider'
    },
    'Contact receiver': {
      'ha': 'Tuntuɓi mai karɓa',
      'ig': 'Kpọtụrụ onye nata',
      'yo': 'Kan si olugba'
    },
    'Use phone or WhatsApp with': {
      'ha': 'Yi amfani da waya ko WhatsApp da',
      'ig': 'Jiri ekwentị ma ọ bụ WhatsApp kpọọ',
      'yo': 'Lo foonu tabi WhatsApp pẹlu'
    },
    'Pick-up OTP': {'ha': 'OTP ɗauka', 'ig': 'OTP iburu', 'yo': 'OTP gbigbe'},
    'Delivery OTP': {
      'ha': 'OTP delivery',
      'ig': 'OTP mbufe',
      'yo': 'OTP ifijiṣẹ'
    },
    'Sender code': {
      'ha': 'Lambar mai aikawa',
      'ig': 'Koodu onye zipụrụ',
      'yo': 'Koodu oluranṣẹ'
    },
    'Receiver code': {
      'ha': 'Lambar mai karɓa',
      'ig': 'Koodu onye nata',
      'yo': 'Koodu olugba'
    },
    'Invalid OTP.': {
      'ha': 'OTP ba daidai ba.',
      'ig': 'OTP ezighi ezi.',
      'yo': 'OTP ko tọ.'
    },
    'Pick-up confirmed.': {
      'ha': 'An tabbatar da ɗauka.',
      'ig': 'A kwadoro iburu.',
      'yo': 'A ti jẹrisi gbigbe.'
    },
    'Delivery confirmed.': {
      'ha': 'An tabbatar da delivery.',
      'ig': 'A kwadoro mbufe.',
      'yo': 'A ti jẹrisi ifijiṣẹ.'
    },
    'Orders': {'ha': 'Orders', 'ig': 'Orders', 'yo': 'Awọn order'},
    'Customers': {
      'ha': 'Abokan ciniki',
      'ig': 'Ndị ahịa',
      'yo': 'Awọn onibara'
    },
    'Riders': {'ha': 'Riders', 'ig': 'Riders', 'yo': 'Riders'},
    'Payments': {'ha': 'Biyan kuɗi', 'ig': 'Ịkwụ ụgwọ', 'yo': 'Isanwo'},
    'Disputes': {'ha': 'Rikice-rikice', 'ig': 'Esemokwu', 'yo': 'Ariyànjiyàn'},
    'Pricing': {'ha': 'Farashi', 'ig': 'Ọnụahịa', 'yo': 'Owo'},
    'Notify': {'ha': 'Sanar', 'ig': 'Zipu ọkwa', 'yo': 'Fi iwifunni ranṣẹ'},
    'Available balance': {
      'ha': 'Kuɗin da ake da shi',
      'ig': 'Ego dị',
      'yo': 'Iye to wa'
    },
    'Add funds': {'ha': 'Ƙara kuɗi', 'ig': 'Tinye ego', 'yo': 'Fi owo kun'},
    'Transaction history': {
      'ha': 'Tarihin ma’amaloli',
      'ig': 'Akụkọ azụmahịa',
      'yo': 'Itan iṣowo'
    },
    'No wallet activity yet': {
      'ha': 'Babu aiki a wallet tukuna',
      'ig': 'Enweghị ọrụ wallet ka ọ dị',
      'yo': 'Ko si iṣẹ wallet sibẹ'
    },
    'Wallet funding will be connected to Paystack top-up.': {
      'ha': 'Za a haɗa ƙara kuɗin wallet da Paystack.',
      'ig': 'A ga-ejikọta itinye ego wallet na Paystack.',
      'yo': 'Fifi owo kun wallet yoo sopọ mọ Paystack.'
    },
    'Delivery booking': {
      'ha': 'Booking delivery',
      'ig': 'Booking mbufe',
      'yo': 'Booking ifijiṣẹ'
    },
    'Email': {'ha': 'Imel', 'ig': 'Email', 'yo': 'Imeeli'},
    'Not set': {'ha': 'Ba a saita ba', 'ig': 'Edebeghị', 'yo': 'Ko ṣeto'},
    'authorized': {'ha': 'an amince', 'ig': 'akwadoro', 'yo': 'ti fọwọsi'},
    'Use current GPS for drop-off': {
      'ha': 'Yi amfani da GPS yanzu don sauke',
      'ig': 'Jiri GPS ugbu a maka idobe',
      'yo': 'Lo GPS lọwọlọwọ fun ibi de'
    },
    'Select an online rider before booking.': {
      'ha': 'Zaɓi rider da yake online kafin booking.',
      'ig': 'Họrọ rider nọ online tupu booking.',
      'yo': 'Yan rider to wa online ṣaaju booking.'
    },
    'Google Map location': {
      'ha': 'Wurin Google Map',
      'ig': 'Ebe Google Map',
      'yo': 'Ipo Google Map'
    },
    'Tap once for pick-up, tap again for drop-off. Drag pins to adjust.': {
      'ha':
          'Danna sau ɗaya don ɗauka, sake dannawa don sauke. Ja pin don gyara.',
      'ig':
          'Pịa otu ugboro maka iburu, pịa ọzọ maka idobe. Dọkpụrụ pin iji dozie.',
      'yo':
          'Tẹ lẹẹkan fun ibi gbigbe, tẹ lẹẹkansi fun ibi de. Fa pin lati ṣatunṣe.'
    },
    'Pick-up': {'ha': 'Ɗauka', 'ig': 'Iburu', 'yo': 'Gbigbe'},
    'Drop-off': {'ha': 'Sauke', 'ig': 'Idobe', 'yo': 'Ibi de'},
    'Select pick-up location first': {
      'ha': 'Da farko zaɓi wurin ɗauka',
      'ig': 'Buru ụzọ họrọ ebe iburu',
      'yo': 'Kọkọ yan ibi gbigbe'
    },
    'Use GPS or tap the Google Map so nearby online riders can load.': {
      'ha':
          'Yi amfani da GPS ko danna Google Map domin riders online na kusa su bayyana.',
      'ig': 'Jiri GPS ma ọ bụ pịa Google Map ka riders nọ online nso pụta.',
      'yo': 'Lo GPS tabi tẹ Google Map ki awọn rider online to sunmọ le han.'
    },
    '1 nearby rider': {
      'ha': 'Rider 1 na kusa',
      'ig': 'Otu rider nọ nso',
      'yo': 'Rider 1 to sunmọ'
    },
    'nearby riders': {
      'ha': 'riders na kusa',
      'ig': 'riders nọ nso',
      'yo': 'riders to sunmọ'
    },
    'No verified online rider is visible in': {
      'ha': 'Babu verified rider online da ake gani a',
      'ig': 'Enweghị verified rider online a hụrụ na',
      'yo': 'Ko si verified rider online ti o han ni'
    },
    'right now.': {'ha': 'yanzu.', 'ig': 'ugbu a.', 'yo': 'bayi.'},
    'Select one online rider for this booking.': {
      'ha': 'Zaɓi rider online guda ɗaya don wannan booking.',
      'ig': 'Họrọ otu rider online maka booking a.',
      'yo': 'Yan rider online kan fun booking yii.'
    },
    'Refresh riders': {
      'ha': 'Sabunta riders',
      'ig': 'Mee riders ka ha dị ọhụrụ',
      'yo': 'Tun riders wa'
    },
    'Search again': {'ha': 'Sake nema', 'ig': 'Chọọ ọzọ', 'yo': 'Wa lẹẹkansi'},
    'Searching for online riders again.': {
      'ha': 'Ana sake neman riders da suke online.',
      'ig': 'A na-achọ riders nọ online ọzọ.',
      'yo': 'A n wa riders online lẹẹkansi.'
    },
    'Pricing is not configured for this city yet.': {
      'ha': 'Ba a saita farashi ga wannan birni ba tukuna.',
      'ig': 'E debeghị ọnụahịa maka obodo a.',
      'yo': 'A ko ti ṣeto owo fun ilu yii.'
    },
    'Pricing not configured': {
      'ha': 'Ba a saita farashi ba',
      'ig': 'E debeghị ọnụahịa',
      'yo': 'A ko ṣeto owo'
    },
    'Ask admin to set pricing for this city before booking.': {
      'ha': 'Nemi admin ya saita farashi ga wannan birni kafin booking.',
      'ig': 'Gwa admin ka o debe ọnụahịa obodo a tupu booking.',
      'yo': 'Beere lọwọ admin lati ṣeto owo fun ilu yii ṣaaju booking.'
    },
    'Describe the drop-off address or landmark clearly.': {
      'ha': 'Bayyana adireshin sauke ko alama sosai.',
      'ig': 'Kọwaa adreesị idobe ma ọ bụ akara ebe nke ọma.',
      'yo': 'Ṣalaye adirẹsi ibi de tabi ami ibi kedere.'
    },
    'Item photo': {'ha': 'Hoton kaya', 'ig': 'Foto ihe', 'yo': 'Fọto nkan'},
    'Snap the item for the rider to see.': {
      'ha': 'Ɗauki hoton kaya don rider ya gani.',
      'ig': 'Were foto ihe ka rider hụ.',
      'yo': 'Ya aworan nkan ki rider le rii.'
    },
    'Camera': {'ha': 'Kamara', 'ig': 'Kamera', 'yo': 'Kamẹra'},
    'Order created, but the item photo could not be uploaded.': {
      'ha': 'An ƙirƙiri order, amma ba a iya upload hoton kaya ba.',
      'ig': 'E mepụtara order, mana enweghị ike ibulite foto ihe.',
      'yo': 'A ṣẹda order, ṣugbọn fọto nkan ko le upload.'
    },
    'Card payment is verified before matching you with a rider.': {
      'ha': 'Ana tabbatar da biyan kati kafin haɗa ka da rider.',
      'ig': 'A na-enyocha ịkwụ kaadị tupu ijikọ gị na rider.',
      'yo': 'A maa jẹrisi isanwo kaadi ṣaaju ki a to ba ọ wa rider.'
    },
    'Address route': {
      'ha': 'Hanyar adireshi',
      'ig': 'Ụzọ adreesị',
      'yo': 'Ọna adirẹsi'
    },
    'Address based route': {
      'ha': 'Hanya bisa adireshi',
      'ig': 'Ụzọ dabere na adreesị',
      'yo': 'Ọna ti o da lori adirẹsi'
    },
    'Open Maps': {'ha': 'Buɗe Maps', 'ig': 'Mepee Maps', 'yo': 'Ṣii Maps'},
    'Are you sure you want to log out?': {
      'ha': 'Kana da tabbacin kana son fita?',
      'ig': 'Ị ji n’aka na ịchọrọ ịpụ?',
      'yo': 'Ṣe o da ọ loju pe o fẹ jade?'
    },
    'Enter your login detail and password.': {
      'ha': 'Shigar da bayanin shiga da kalmar sirri.',
      'ig': 'Tinye nkọwa nbanye na paswọọdụ gị.',
      'yo': 'Tẹ alaye wiwọle ati ọrọigbaniwọle rẹ sii.'
    },
    'Invalid login details or password.': {
      'ha': 'Bayanan shiga ko kalmar sirri ba daidai ba.',
      'ig': 'Nkọwa nbanye ma ọ bụ paswọọdụ ezighi ezi.',
      'yo': 'Alaye wiwọle tabi ọrọigbaniwọle ko tọ.'
    },
    'Too many attempts. Please try again later.': {
      'ha': 'An yi ƙoƙari da yawa. A sake gwadawa daga baya.',
      'ig': 'Mgbalị karịrị akarị. Biko nwaa ọzọ ma emechaa.',
      'yo': 'Igbiyanju ti pọ ju. Jọwọ gbiyanju nigbamii.'
    },
    'Login failed. Please try again.': {
      'ha': 'Shiga ya kasa. Da fatan a sake gwadawa.',
      'ig': 'Nbanye dara. Biko nwaa ọzọ.',
      'yo': 'Wiwọle kuna. Jọwọ gbiyanju lẹẹkansi.'
    },
    'This account has no CarryGo profile. Contact support.': {
      'ha': 'Wannan asusun ba shi da profile na CarryGo. Tuntuɓi support.',
      'ig': 'Akaụntụ a enweghị profaịlụ CarryGo. Kpọtụrụ support.',
      'yo': 'Akaunti yii ko ni profaili CarryGo. Kan si support.'
    },
    'Confirm booking': {
      'ha': 'Tabbatar da booking',
      'ig': 'Kwenye booking',
      'yo': 'Jẹrisi booking'
    },
    'Please confirm that the pickup, drop-off, parcel and payment details are correct before booking a rider.':
        {
      'ha':
          'Da fatan tabbatar cewa bayanan ɗauka, sauke, kaya da biya daidai ne kafin booking rider.',
      'ig':
          'Biko kwenye na nkọwa iburu, idobe, ngwugwu na ịkwụ ụgwọ ziri ezi tupu booking rider.',
      'yo':
          'Jọwọ jẹrisi pe alaye gbigbe, ibi de, ẹru ati isanwo tọ ṣaaju booking rider.'
    },
    'Account creation successful. Welcome to CarryGo.': {
      'ha': 'An ƙirƙiri asusu cikin nasara. Barka da zuwa CarryGo.',
      'ig': 'Emeputara akaụntụ nke oma. Nnọọ na CarryGo.',
      'yo': 'Ṣiṣẹda akaunti ṣaṣeyọri. Kaabo si CarryGo.'
    },
    'Account creation request received. You will be informed once admin approves your account.':
        {
      'ha':
          'An karɓi buƙatar ƙirƙirar asusu. Za a sanar da kai idan admin ya amince.',
      'ig': 'Anatara arịrịọ imepụta akaụntụ. A ga-agwa gị mgbe admin kwadoro.',
      'yo':
          'A ti gba ibeere ṣiṣeda akaunti. A o sọ fun ọ nigbati admin ba fọwọsi.'
    },
    'Delete account': {
      'ha': 'Goge asusu',
      'ig': 'Hichapụ akaụntụ',
      'yo': 'Pa akaunti rẹ'
    },
    'Permanently delete your account and profile data.': {
      'ha': 'Goge asusunka da bayanan profile har abada.',
      'ig': 'Hichapụ akaụntụ na profaịlụ gị kpamkpam.',
      'yo': 'Pa akaunti ati data profaili rẹ patapata.'
    },
    'Delete account permanently?': {
      'ha': 'A goge asusu har abada?',
      'ig': 'Ị ga-ehichapụ akaụntụ kpamkpam?',
      'yo': 'Ṣe ki a pa akaunti rẹ patapata?'
    },
    'This will permanently remove your CarryGo account profile from Firestore and delete your login account. You can create a new account later with the same email or phone number.':
        {
      'ha':
          'Wannan zai cire profile ɗin CarryGo daga Firestore kuma ya goge asusun shiga. Za ka iya sake ƙirƙirar asusu da imel ko waya ɗaya daga baya.',
      'ig':
          'Nke a ga-ewepụ profaịlụ CarryGo gị na Firestore ma hichapụ akaụntụ nbanye gị. Ị nwere ike iji otu email ma ọ bụ ekwentị mepụta akaụntụ ọzọ ma emechaa.',
      'yo':
          'Eyi yoo yọ profaili CarryGo rẹ kuro ni Firestore patapata ati pa akaunti iwọle rẹ. O le ṣẹda akaunti tuntun nigbamii pẹlu imeeli tabi foonu kanna.'
    },
    'I understand that this account deletion cannot be undone.': {
      'ha': 'Na fahimci cewa ba za a iya dawo da wannan gogewar ba.',
      'ig': 'Aghọtara m na enweghị ike iweghachi nhichapụ a.',
      'yo': 'Mo ye mi pe pipaarẹ yii ko le yipada.'
    },
    'Deleting...': {
      'ha': 'Ana gogewa...',
      'ig': 'Na-ehichapụ...',
      'yo': 'N pa...'
    },
    'Account deleted successfully.': {
      'ha': 'An goge asusu cikin nasara.',
      'ig': 'Ehichapụla akaụntụ nke ọma.',
      'yo': 'A ti pa akaunti naa ni aṣeyọri.'
    },
    'Enter your password to delete account.': {
      'ha': 'Shigar da kalmar sirri don goge asusu.',
      'ig': 'Tinye paswọọdụ gị iji hichapụ akaụntụ.',
      'yo': 'Tẹ ọrọigbaniwọle rẹ lati pa akaunti.'
    },
    'This account cannot be deleted here. Please contact support.': {
      'ha': 'Ba za a iya goge wannan asusu a nan ba. Tuntuɓi support.',
      'ig': 'Enweghị ike ihichapụ akaụntụ a ebe a. Kpọtụrụ support.',
      'yo': 'A ko le pa akaunti yii nibi. Kan si support.'
    },
    'Re-authentication failed.': {
      'ha': 'Sake tabbatar da shiga ya kasa.',
      'ig': 'Nkwenye nbanye ọzọ dara.',
      'yo': 'Atun-jẹrisi iwọle kuna.'
    },
  };
}
