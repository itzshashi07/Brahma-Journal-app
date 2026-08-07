/// Bhagavad Gita verses mapped to situations people actually find themselves in.
///
/// Each entry carries the Sanskrit, a transliteration, a translation and — the
/// point of the section — how the verse applies to a real modern situation,
/// written in both English and Hindi.
///
/// **On accuracy:** chapter and verse references are given so every entry can be
/// checked against a printed edition. The Sanskrit is included for readers who
/// want it, but the app leads with the meaning: a verse nobody understands
/// consoles nobody. Have a knowledgeable reader review this file before a wide
/// release — misquoting scripture in a spiritual app is a serious thing to get
/// wrong, and it is the one part of this app that cannot be caught by a test.
library;

enum GitaSituation {
  heartbreak,
  anxiety,
  fear,
  career,
  outOfControl,
  loss,
  anger,
  selfDoubt,
  growth,
  purpose,
  attachment,
  peace,
}

extension GitaSituationInfo on GitaSituation {
  String get labelEn => switch (this) {
        GitaSituation.heartbreak => 'Heartbreak',
        GitaSituation.anxiety => 'Anxiety',
        GitaSituation.fear => 'Fear',
        GitaSituation.career => 'Career & Work',
        GitaSituation.outOfControl => 'Out of Control',
        GitaSituation.loss => 'Grief & Loss',
        GitaSituation.anger => 'Anger',
        GitaSituation.selfDoubt => 'Self-Doubt',
        GitaSituation.growth => 'Growth',
        GitaSituation.purpose => 'Purpose',
        GitaSituation.attachment => 'Letting Go',
        GitaSituation.peace => 'Inner Peace',
      };

  String get labelHi => switch (this) {
        GitaSituation.heartbreak => 'दिल टूटना',
        GitaSituation.anxiety => 'चिंता',
        GitaSituation.fear => 'डर',
        GitaSituation.career => 'करियर और काम',
        GitaSituation.outOfControl => 'बेबसी',
        GitaSituation.loss => 'शोक',
        GitaSituation.anger => 'क्रोध',
        GitaSituation.selfDoubt => 'आत्म-संदेह',
        GitaSituation.growth => 'विकास',
        GitaSituation.purpose => 'उद्देश्य',
        GitaSituation.attachment => 'मोह छोड़ना',
        GitaSituation.peace => 'शांति',
      };

  String get emoji => switch (this) {
        GitaSituation.heartbreak => '💔',
        GitaSituation.anxiety => '😰',
        GitaSituation.fear => '😨',
        GitaSituation.career => '💼',
        GitaSituation.outOfControl => '🌪️',
        GitaSituation.loss => '🕊️',
        GitaSituation.anger => '🔥',
        GitaSituation.selfDoubt => '🪞',
        GitaSituation.growth => '🌱',
        GitaSituation.purpose => '🧭',
        GitaSituation.attachment => '🍃',
        GitaSituation.peace => '☮️',
      };
}

class GitaVerse {
  final int chapter;
  final int verse;
  final String sanskrit;
  final String transliteration;
  final String translationEn;
  final String translationHi;

  /// The whole point of the section: what this means when you are living it.
  final String applicationEn;
  final String applicationHi;

  final List<GitaSituation> situations;

  const GitaVerse({
    required this.chapter,
    required this.verse,
    required this.sanskrit,
    required this.transliteration,
    required this.translationEn,
    required this.translationHi,
    required this.applicationEn,
    required this.applicationHi,
    required this.situations,
  });

  String get reference => 'Chapter $chapter, Verse $verse';
}

class GitaLibrary {
  static const List<GitaVerse> verses = [
    // ─────────────────────── action without attachment ───────────────────────
    GitaVerse(
      chapter: 2,
      verse: 47,
      sanskrit:
          'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि॥',
      transliteration:
          'karmaṇy-evādhikāras te mā phaleṣu kadācana\nmā karma-phala-hetur bhūr mā te saṅgo \'stv akarmaṇi',
      translationEn:
          'You have a right to your actions, but never to the fruits of your actions. Do not let the fruit be your motive, nor let yourself be attached to inaction.',
      translationHi:
          'तुम्हारा अधिकार केवल कर्म करने में है, उसके फलों में कभी नहीं। न फल की इच्छा से कर्म करो, और न ही कर्म छोड़ने में आसक्त हो।',
      applicationEn:
          'You prepared for months and did not get the offer. You gave everything to a relationship and it still ended. This verse is not telling you results do not matter — it is telling you they were never the part you controlled. Your effort was real and it was yours. The outcome depended on a hundred things outside you. Judge yourself on what you actually held in your hands.',
      applicationHi:
          'महीनों तैयारी की और नौकरी नहीं मिली। रिश्ते में सब कुछ दिया, फिर भी टूट गया। यह श्लोक यह नहीं कहता कि परिणाम मायने नहीं रखते — यह कहता है कि परिणाम कभी तुम्हारे हाथ में था ही नहीं। तुम्हारी मेहनत असली थी और तुम्हारी थी। खुद को उसी से आँको जो सच में तुम्हारे हाथ में था।',
      situations: [
        GitaSituation.career,
        GitaSituation.outOfControl,
        GitaSituation.anxiety,
      ],
    ),
    GitaVerse(
      chapter: 2,
      verse: 48,
      sanskrit:
          'योगस्थः कुरु कर्माणि सङ्गं त्यक्त्वा धनञ्जय।\nसिद्ध्यसिद्ध्योः समो भूत्वा समत्वं योग उच्यते॥',
      transliteration:
          'yoga-sthaḥ kuru karmāṇi saṅgaṁ tyaktvā dhanañjaya\nsiddhy-asiddhyoḥ samo bhūtvā samatvaṁ yoga ucyate',
      translationEn:
          'Established in yoga, perform your work, abandoning attachment, remaining balanced in success and failure. This evenness of mind is called yoga.',
      translationHi:
          'हे धनञ्जय, योग में स्थित होकर, आसक्ति त्यागकर, सफलता और असफलता में समान रहकर कर्म करो। यही समत्व योग कहलाता है।',
      applicationEn:
          'The promotion and the rejection both pass. If your peace rises and falls with each result, you have handed the steering wheel to events. Evenness is not indifference — it is refusing to let a single outcome decide who you are that week.',
      applicationHi:
          'तरक्की भी गुज़र जाती है और अस्वीकृति भी। अगर तुम्हारी शांति हर परिणाम के साथ ऊपर-नीचे होती है, तो तुमने अपनी गाड़ी का स्टीयरिंग हालात को दे दिया है। समता उदासीनता नहीं है — यह इनकार है कि कोई एक परिणाम तय करे कि उस हफ़्ते तुम कौन हो।',
      situations: [
        GitaSituation.career,
        GitaSituation.peace,
        GitaSituation.growth,
      ],
    ),

    // ─────────────────────── the self is untouched ───────────────────────
    GitaVerse(
      chapter: 2,
      verse: 20,
      sanskrit:
          'न जायते म्रियते वा कदाचिन्नायं भूत्वा भविता वा न भूयः।\nअजो नित्यः शाश्वतोऽयं पुराणो न हन्यते हन्यमाने शरीरे॥',
      transliteration:
          'na jāyate mriyate vā kadācin nāyaṁ bhūtvā bhavitā vā na bhūyaḥ\najo nityaḥ śāśvato \'yaṁ purāṇo na hanyate hanyamāne śarīre',
      translationEn:
          'The soul is never born and never dies. It has not come into being, does not come into being, and will not come into being. It is unborn, eternal, everlasting and ancient. It is not slain when the body is slain.',
      translationHi:
          'आत्मा न कभी जन्म लेती है, न मरती है। यह अजन्मा, नित्य, शाश्वत और पुरातन है। शरीर के नष्ट होने पर भी यह नष्ट नहीं होती।',
      applicationEn:
          'When you lose someone, the mind keeps reaching for a person who is no longer answering. This verse offers one steady thought to hold: what you loved in them was never the body that stopped. Grief is not a failure of faith — but you can grieve the absence without believing they have been erased.',
      applicationHi:
          'जब कोई चला जाता है, मन बार-बार उसी इंसान को ढूँढता है जो अब जवाब नहीं देता। यह श्लोक एक स्थिर विचार देता है: जो तुम्हें उनमें प्रिय था, वह कभी वह शरीर था ही नहीं जो रुक गया। शोक करना विश्वास की कमी नहीं है — पर तुम उनकी अनुपस्थिति का दुःख मना सकते हो, यह माने बिना कि वे मिट गए।',
      situations: [GitaSituation.loss, GitaSituation.fear],
    ),
    GitaVerse(
      chapter: 2,
      verse: 22,
      sanskrit:
          'वासांसि जीर्णानि यथा विहाय नवानि गृह्णाति नरोऽपराणि।\nतथा शरीराणि विहाय जीर्णान्यन्यानि संयाति नवानि देही॥',
      transliteration:
          'vāsāṁsi jīrṇāni yathā vihāya navāni gṛhṇāti naro \'parāṇi\ntathā śarīrāṇi vihāya jīrṇāny anyāni saṁyāti navāni dehī',
      translationEn:
          'As a person casts off worn-out garments and puts on new ones, so the embodied soul casts off worn-out bodies and takes on new ones.',
      translationHi:
          'जैसे मनुष्य पुराने वस्त्र त्यागकर नए वस्त्र धारण करता है, वैसे ही आत्मा पुराने शरीर छोड़कर नए शरीर धारण करती है।',
      applicationEn:
          'Endings feel like erasure. This image reframes them as change of form: the chapter closed, not the story. It applies past bereavement too — the version of you that ended a relationship, left a city, lost a job, was also a garment you have outgrown.',
      applicationHi:
          'अंत मिटने जैसा लगता है। यह उपमा उसे रूप-परिवर्तन बताती है: अध्याय बंद हुआ, कहानी नहीं। यह मृत्यु से आगे भी लागू है — तुम्हारा वह रूप जिसने रिश्ता तोड़ा, शहर छोड़ा, नौकरी खोई, वह भी एक वस्त्र था जो अब छोटा पड़ गया।',
      situations: [
        GitaSituation.loss,
        GitaSituation.heartbreak,
        GitaSituation.growth,
      ],
    ),

    // ─────────────────────── anxiety and the restless mind ───────────────────
    GitaVerse(
      chapter: 6,
      verse: 5,
      sanskrit:
          'उद्धरेदात्मनात्मानं नात्मानमवसादयेत्।\nआत्मैव ह्यात्मनो बन्धुरात्मैव रिपुरात्मनः॥',
      transliteration:
          'uddhared ātmanātmānaṁ nātmānam avasādayet\nātmaiva hy ātmano bandhur ātmaiva ripur ātmanaḥ',
      translationEn:
          'Lift yourself by yourself; do not let yourself sink. For the self alone is the friend of the self, and the self alone is its enemy.',
      translationHi:
          'अपने द्वारा अपना उद्धार करो, स्वयं को गिरने मत दो। क्योंकि मनुष्य स्वयं ही अपना मित्र है और स्वयं ही अपना शत्रु।',
      applicationEn:
          'Notice how you speak to yourself after a mistake. You would not tolerate that tone from anyone else. The same mind that replays your failures at 2am is the one that can steady you — it takes instruction from whoever is speaking loudest. Decide to be that voice.',
      applicationHi:
          'ध्यान दो कि गलती के बाद तुम खुद से कैसे बात करते हो। किसी और से वह लहजा तुम बर्दाश्त नहीं करते। जो मन रात दो बजे तुम्हारी असफलताएँ दोहराता है, वही तुम्हें सँभाल भी सकता है — वह उसी की सुनता है जो सबसे ज़ोर से बोले। तय करो कि वह आवाज़ तुम्हारी हो।',
      situations: [
        GitaSituation.selfDoubt,
        GitaSituation.anxiety,
        GitaSituation.growth,
      ],
    ),
    GitaVerse(
      chapter: 6,
      verse: 35,
      sanskrit:
          'असंशयं महाबाहो मनो दुर्निग्रहं चलम्।\nअभ्यासेन तु कौन्तेय वैराग्येण च गृह्यते॥',
      transliteration:
          'asaṁśayaṁ mahā-bāho mano durnigrahaṁ calam\nabhyāsena tu kaunteya vairāgyeṇa ca gṛhyate',
      translationEn:
          'Undoubtedly the mind is restless and hard to restrain. But by practice and by detachment it can be held.',
      translationHi:
          'निःसंदेह मन चंचल है और वश में करना कठिन है। परन्तु हे कौन्तेय, अभ्यास और वैराग्य से यह वश में होता है।',
      applicationEn:
          'Krishna does not tell Arjuna the mind is easy. He agrees it is hard, then names the only two things that work: repetition, and loosening your grip. If meditation felt impossible today, you are not failing — you are at the beginning of the exact process described here.',
      applicationHi:
          'कृष्ण अर्जुन से यह नहीं कहते कि मन को साधना आसान है। वे मानते हैं कि यह कठिन है, फिर वही दो चीज़ें बताते हैं जो काम करती हैं: अभ्यास और पकड़ ढीली करना। अगर आज ध्यान असंभव लगा, तो तुम असफल नहीं हो — तुम ठीक उसी प्रक्रिया की शुरुआत में हो।',
      situations: [
        GitaSituation.anxiety,
        GitaSituation.peace,
        GitaSituation.growth,
      ],
    ),
    GitaVerse(
      chapter: 6,
      verse: 26,
      sanskrit:
          'यतो यतो निश्चरति मनश्चञ्चलमस्थिरम्।\nततस्ततो नियम्यैतदात्मन्येव वशं नयेत्॥',
      transliteration:
          'yato yato niścarati manaś cañcalam asthiram\ntatas tato niyamyaitad ātmany eva vaśaṁ nayet',
      translationEn:
          'Wherever the restless and unsteady mind wanders, from there withdraw it and bring it back under the control of the self.',
      translationHi:
          'यह चंचल और अस्थिर मन जहाँ-जहाँ भटके, वहाँ-वहाँ से हटाकर इसे बार-बार आत्मा के वश में लाओ।',
      applicationEn:
          'This is the entire instruction for meditation, and it assumes you will wander. Not "do not think" — but "notice, and come back." Every return is the practice succeeding, not failing. A hundred returns in ten minutes is a hundred repetitions.',
      applicationHi:
          'यह ध्यान का पूरा निर्देश है, और यह मान कर चलता है कि मन भटकेगा। "मत सोचो" नहीं — बल्कि "देखो, और लौट आओ।" हर वापसी अभ्यास की सफलता है, असफलता नहीं। दस मिनट में सौ बार लौटना, सौ अभ्यास हैं।',
      situations: [GitaSituation.anxiety, GitaSituation.peace],
    ),

    // ─────────────────────── fear and refuge ───────────────────────
    GitaVerse(
      chapter: 18,
      verse: 66,
      sanskrit:
          'सर्वधर्मान्परित्यज्य मामेकं शरणं व्रज।\nअहं त्वां सर्वपापेभ्यो मोक्ष्यिष्यामि मा शुचः॥',
      transliteration:
          'sarva-dharmān parityajya mām ekaṁ śaraṇaṁ vraja\nahaṁ tvāṁ sarva-pāpebhyo mokṣayiṣyāmi mā śucaḥ',
      translationEn:
          'Abandon all varieties of duty and take refuge in Me alone. I shall free you from all sin. Do not grieve.',
      translationHi:
          'सब धर्मों को त्यागकर केवल मेरी शरण में आओ। मैं तुम्हें सब पापों से मुक्त कर दूँगा, शोक मत करो।',
      applicationEn:
          'Sometimes you have carried a decision alone for so long that the weight itself has become the problem. "Do not grieve" is the last thing Krishna says to Arjuna — after all the philosophy, the closing note is reassurance. You are allowed to set something down.',
      applicationHi:
          'कभी-कभी तुमने कोई फैसला इतने लंबे समय तक अकेले उठाया है कि बोझ ही समस्या बन गया है। "शोक मत करो" — यही आख़िरी बात कृष्ण अर्जुन से कहते हैं। सारे दर्शन के बाद, अंतिम स्वर आश्वासन का है। तुम्हें कुछ नीचे रखने की अनुमति है।',
      situations: [
        GitaSituation.fear,
        GitaSituation.outOfControl,
        GitaSituation.anxiety,
      ],
    ),
    GitaVerse(
      chapter: 4,
      verse: 7,
      sanskrit:
          'यदा यदा हि धर्मस्य ग्लानिर्भवति भारत।\nअभ्युत्थानमधर्मस्य तदात्मानं सृजाम्यहम्॥',
      transliteration:
          'yadā yadā hi dharmasya glānir bhavati bhārata\nabhyutthānam adharmasya tadātmānaṁ sṛjāmy aham',
      translationEn:
          'Whenever righteousness declines and unrighteousness rises, then I manifest Myself.',
      translationHi:
          'हे भारत, जब-जब धर्म की हानि और अधर्म की वृद्धि होती है, तब-तब मैं स्वयं को प्रकट करता हूँ।',
      applicationEn:
          'Read at the scale of a life rather than an age: the moments things fall apart are often exactly when something in you is called forward. The version of you that handles this does not exist yet — it is created by the situation demanding it.',
      applicationHi:
          'इसे युग के बजाय एक जीवन के पैमाने पर पढ़ो: जब चीज़ें बिखरती हैं, अक्सर वही क्षण होता है जब तुम्हारे भीतर कुछ आगे बुलाया जाता है। तुम्हारा वह रूप जो इसे सँभालेगा, अभी मौजूद नहीं है — वह इसी परिस्थिति की माँग से बनता है।',
      situations: [
        GitaSituation.outOfControl,
        GitaSituation.fear,
        GitaSituation.growth,
      ],
    ),

    // ─────────────────────── anger ───────────────────────
    GitaVerse(
      chapter: 2,
      verse: 62,
      sanskrit:
          'ध्यायतो विषयान्पुंसः सङ्गस्तेषूपजायते।\nसङ्गात्सञ्जायते कामः कामात्क्रोधोऽभिजायते॥',
      transliteration:
          'dhyāyato viṣayān puṁsaḥ saṅgas teṣūpajāyate\nsaṅgāt sañjāyate kāmaḥ kāmāt krodho \'bhijāyate',
      translationEn:
          'Dwelling on objects of the senses breeds attachment to them. From attachment desire is born, and from desire arises anger.',
      translationHi:
          'विषयों का चिंतन करने से उनमें आसक्ति होती है, आसक्ति से कामना जन्म लेती है, और कामना से क्रोध उत्पन्न होता है।',
      applicationEn:
          'Anger is rarely the first step. Trace it back: you wanted something, you wanted it because you had been turning it over in your mind. Catching the chain early — at the dwelling, not the explosion — is far easier than trying to stop yourself mid-shout.',
      applicationHi:
          'क्रोध शायद ही पहला कदम होता है। पीछे जाकर देखो: तुम्हें कुछ चाहिए था, और चाहिए इसलिए था क्योंकि तुम उसे मन में दोहरा रहे थे। इस श्रृंखला को शुरू में पकड़ना — चिंतन पर, विस्फोट पर नहीं — चिल्लाते-चिल्लाते रुकने से कहीं आसान है।',
      situations: [GitaSituation.anger, GitaSituation.attachment],
    ),
    GitaVerse(
      chapter: 2,
      verse: 63,
      sanskrit:
          'क्रोधाद्भवति सम्मोहः सम्मोहात्स्मृतिविभ्रमः।\nस्मृतिभ्रंशाद् बुद्धिनाशो बुद्धिनाशात्प्रणश्यति॥',
      transliteration:
          'krodhād bhavati sammohaḥ sammohāt smṛti-vibhramaḥ\nsmṛti-bhraṁśād buddhi-nāśo buddhi-nāśāt praṇaśyati',
      translationEn:
          'From anger comes delusion; from delusion, confusion of memory; from confusion of memory, loss of reason; and from loss of reason one is lost.',
      translationHi:
          'क्रोध से मोह उत्पन्न होता है, मोह से स्मृति भ्रमित होती है, स्मृति भ्रम से बुद्धि नष्ट होती है, और बुद्धि नष्ट होने से मनुष्य का पतन होता है।',
      applicationEn:
          'This is the most precise description of losing your temper ever written. Angry, you forget what you know about the person. Forgetting, you say the thing you cannot take back. The verse is a warning about the sequence, and the only place to intervene is the first link.',
      applicationHi:
          'गुस्सा खोने का इससे सटीक वर्णन कहीं नहीं लिखा गया। क्रोध में तुम भूल जाते हो कि तुम उस इंसान के बारे में क्या जानते हो। भूलकर तुम वह कह देते हो जो वापस नहीं लिया जा सकता। यह श्लोक क्रम की चेतावनी है, और रोकने की जगह सिर्फ़ पहली कड़ी है।',
      situations: [GitaSituation.anger],
    ),

    // ─────────────────────── self-doubt and purpose ───────────────────────
    GitaVerse(
      chapter: 3,
      verse: 35,
      sanskrit:
          'श्रेयान्स्वधर्मो विगुणः परधर्मात्स्वनुष्ठितात्।\nस्वधर्मे निधनं श्रेयः परधर्मो भयावहः॥',
      transliteration:
          'śreyān sva-dharmo viguṇaḥ para-dharmāt sv-anuṣṭhitāt\nsva-dharme nidhanaṁ śreyaḥ para-dharmo bhayāvahaḥ',
      translationEn:
          'Better one\'s own duty imperfectly performed than the duty of another performed well. Better to fail in one\'s own path than to succeed in another\'s.',
      translationHi:
          'दूसरे के धर्म को अच्छी तरह निभाने से अपना धर्म कम अच्छे से निभाना श्रेष्ठ है। अपने धर्म में मृत्यु भी कल्याणकारी है, पराया धर्म भयावह है।',
      applicationEn:
          'The clearest answer the Gita gives to comparison. Someone else is further ahead in a life that was never yours to live. Doing your own work badly is still the right direction; doing theirs perfectly is not.',
      applicationHi:
          'तुलना का सबसे स्पष्ट उत्तर गीता यहीं देती है। कोई और उस जीवन में आगे है जो कभी तुम्हारा जीने को था ही नहीं। अपना काम ख़राब करना भी सही दिशा है; उनका काम पूरी तरह करना नहीं।',
      situations: [
        GitaSituation.selfDoubt,
        GitaSituation.career,
        GitaSituation.purpose,
      ],
    ),
    GitaVerse(
      chapter: 6,
      verse: 6,
      sanskrit:
          'बन्धुरात्मात्मनस्तस्य येनात्मैवात्मना जितः।\nअनात्मनस्तु शत्रुत्वे वर्तेतात्मैव शत्रुवत्॥',
      transliteration:
          'bandhur ātmātmanas tasya yenātmaivātmanā jitaḥ\nanātmanas tu śatrutve vartetātmaiva śatru-vat',
      translationEn:
          'For one who has conquered the self, the self is a friend. But for one who has not, the self remains hostile like an enemy.',
      translationHi:
          'जिसने स्वयं को जीत लिया है, उसके लिए आत्मा मित्र है। परन्तु जिसने नहीं जीता, उसके लिए वही आत्मा शत्रु के समान रहती है।',
      applicationEn:
          'The person who keeps sabotaging your progress is usually the one making the decisions. Not a character flaw — a habit that can be trained, one honest day at a time.',
      applicationHi:
          'जो व्यक्ति बार-बार तुम्हारी प्रगति रोकता है, वह अक्सर वही है जो फैसले ले रहा है। यह चरित्र का दोष नहीं — यह एक आदत है जिसे प्रशिक्षित किया जा सकता है, एक ईमानदार दिन के बाद दूसरा।',
      situations: [GitaSituation.selfDoubt, GitaSituation.growth],
    ),

    // ─────────────────────── letting go ───────────────────────
    GitaVerse(
      chapter: 2,
      verse: 14,
      sanskrit:
          'मात्रास्पर्शास्तु कौन्तेय शीतोष्णसुखदुःखदाः।\nआगमापायिनोऽनित्यास्तांस्तितिक्षस्व भारत॥',
      transliteration:
          'mātrā-sparśās tu kaunteya śītoṣṇa-sukha-duḥkha-dāḥ\nāgamāpāyino \'nityās tāṁs titikṣasva bhārata',
      translationEn:
          'Contact with the world brings cold and heat, pleasure and pain. They come and go and are impermanent. Endure them, O Bharata.',
      translationHi:
          'हे कौन्तेय, इंद्रियों का विषयों से संपर्क सर्दी-गर्मी और सुख-दुःख देता है। ये आते-जाते रहते हैं, अनित्य हैं। हे भारत, इन्हें सहन करो।',
      applicationEn:
          'The heartbreak you are inside right now has a shape and an end, even though it does not feel like it at 3am. "They come and go" is not dismissal — it is the most useful fact available to you tonight. You do not have to fix this feeling. You have to outlast it.',
      applicationHi:
          'जिस दर्द के भीतर तुम अभी हो, उसका एक आकार है और एक अंत, भले ही रात तीन बजे ऐसा न लगे। "ये आते-जाते हैं" उपेक्षा नहीं है — आज रात तुम्हारे पास यही सबसे काम की सच्चाई है। तुम्हें इस भाव को ठीक नहीं करना है। तुम्हें इससे ज़्यादा टिकना है।',
      situations: [
        GitaSituation.heartbreak,
        GitaSituation.loss,
        GitaSituation.anxiety,
      ],
    ),
    GitaVerse(
      chapter: 12,
      verse: 15,
      sanskrit:
          'यस्मान्नोद्विजते लोको लोकान्नोद्विजते च यः।\nहर्षामर्षभयोद्वेगैर्मुक्तो यः स च मे प्रियः॥',
      transliteration:
          'yasmān nodvijate loko lokān nodvijate ca yaḥ\nharṣāmarṣa-bhayodvegair mukto yaḥ sa ca me priyaḥ',
      translationEn:
          'One by whom the world is not disturbed and who is not disturbed by the world, who is free from elation, envy, fear and anxiety — that one is dear to Me.',
      translationHi:
          'जिससे संसार विचलित नहीं होता और जो स्वयं संसार से विचलित नहीं होता, जो हर्ष, ईर्ष्या, भय और चिंता से मुक्त है — वह मुझे प्रिय है।',
      applicationEn:
          'Note that envy sits in the same list as fear and anxiety. Scrolling through other people\'s lives disturbs you in exactly the way described here. The freedom offered is not from other people succeeding — it is from needing their success to mean something about you.',
      applicationHi:
          'ध्यान दो कि ईर्ष्या उसी सूची में है जिसमें भय और चिंता। दूसरों की ज़िंदगी स्क्रॉल करना तुम्हें ठीक उसी तरह विचलित करता है जैसा यहाँ कहा गया है। जो मुक्ति दी जा रही है वह दूसरों की सफलता से नहीं — बल्कि इस ज़रूरत से है कि उनकी सफलता तुम्हारे बारे में कुछ कहे।',
      situations: [
        GitaSituation.peace,
        GitaSituation.selfDoubt,
        GitaSituation.attachment,
      ],
    ),
    GitaVerse(
      chapter: 5,
      verse: 10,
      sanskrit:
          'ब्रह्मण्याधाय कर्माणि सङ्गं त्यक्त्वा करोति यः।\nलिप्यते न स पापेन पद्मपत्रमिवाम्भसा॥',
      transliteration:
          'brahmaṇy ādhāya karmāṇi saṅgaṁ tyaktvā karoti yaḥ\nlipyate na sa pāpena padma-patram ivāmbhasā',
      translationEn:
          'One who acts having offered all actions, abandoning attachment, is untouched by sin — as a lotus leaf is untouched by water.',
      translationHi:
          'जो आसक्ति त्यागकर सब कर्म परमात्मा को अर्पित करके करता है, वह पाप से वैसे ही अलिप्त रहता है जैसे कमल का पत्ता जल से।',
      applicationEn:
          'The lotus sits in the water without absorbing it. You can be fully in a demanding job, a difficult family, a stressful city, without letting it soak through. Presence and absorption are not the same thing.',
      applicationHi:
          'कमल पानी में रहता है पर उसे सोखता नहीं। तुम पूरी तरह एक मुश्किल नौकरी, कठिन परिवार, तनावभरे शहर में रह सकते हो, बिना उसे भीतर तक उतरने दिए। उपस्थित होना और डूब जाना एक बात नहीं है।',
      situations: [
        GitaSituation.career,
        GitaSituation.peace,
        GitaSituation.attachment,
      ],
    ),

    // ─────────────────────── steadiness and peace ───────────────────────
    GitaVerse(
      chapter: 2,
      verse: 70,
      sanskrit:
          'आपूर्यमाणमचलप्रतिष्ठं समुद्रमापः प्रविशन्ति यद्वत्।\nतद्वत्कामा यं प्रविशन्ति सर्वे स शान्तिमाप्नोति न कामकामी॥',
      transliteration:
          'āpūryamāṇam acala-pratiṣṭhaṁ samudram āpaḥ praviśanti yadvat\ntadvat kāmā yaṁ praviśanti sarve sa śāntim āpnoti na kāma-kāmī',
      translationEn:
          'As rivers flow into the ocean, which remains full and unmoved, so desires enter one who is at peace — not one who chases desire.',
      translationHi:
          'जैसे नदियाँ समुद्र में समाती हैं और समुद्र भरा तथा अचल रहता है, वैसे ही सब कामनाएँ जिसमें समा जाती हैं वही शांति पाता है, कामनाओं के पीछे भागने वाला नहीं।',
      applicationEn:
          'Desires still arrive. The ocean does not stop rivers — it is simply large enough that they do not change its level. Peace is not an empty mind; it is a mind with enough room that a passing want does not become an emergency.',
      applicationHi:
          'कामनाएँ फिर भी आती हैं। समुद्र नदियों को रोकता नहीं — वह बस इतना विशाल है कि उनसे उसका स्तर नहीं बदलता। शांति खाली मन नहीं है; यह इतना बड़ा मन है कि एक गुज़रती इच्छा आपातकाल न बन जाए।',
      situations: [GitaSituation.peace, GitaSituation.attachment],
    ),
    GitaVerse(
      chapter: 6,
      verse: 19,
      sanskrit:
          'यथा दीपो निवातस्थो नेङ्गते सोपमा स्मृता।\nयोगिनो यतचित्तस्य युञ्जतो योगमात्मनः॥',
      transliteration:
          'yathā dīpo nivāta-stho neṅgate sopamā smṛtā\nyogino yata-cittasya yuñjato yogam ātmanaḥ',
      translationEn:
          'As a lamp in a windless place does not flicker, so is the disciplined mind of one absorbed in the self.',
      translationHi:
          'जैसे वायुरहित स्थान में रखा दीपक नहीं काँपता, वैसे ही आत्मा में लीन योगी का संयमित मन स्थिर रहता है।',
      applicationEn:
          'The flame is not fighting the wind; it is simply somewhere the wind cannot reach. That is what a few quiet minutes each morning build — not force of will, but a sheltered place you can return to when the day gets loud.',
      applicationHi:
          'लौ हवा से लड़ नहीं रही; वह बस वहाँ है जहाँ हवा पहुँच नहीं सकती। हर सुबह के कुछ शांत मिनट यही बनाते हैं — इच्छाशक्ति नहीं, बल्कि एक आश्रय जहाँ दिन के शोर में तुम लौट सको।',
      situations: [GitaSituation.peace, GitaSituation.anxiety],
    ),
    GitaVerse(
      chapter: 2,
      verse: 71,
      sanskrit:
          'विहाय कामान्यः सर्वान्पुमांश्चरति निःस्पृहः।\nनिर्ममो निरहङ्कारः स शान्तिमधिगच्छति॥',
      transliteration:
          'vihāya kāmān yaḥ sarvān pumāṁś carati niḥspṛhaḥ\nnirmamo nirahaṅkāraḥ sa śāntim adhigacchati',
      translationEn:
          'One who abandons all cravings and moves through life free from longing, without the sense of "mine" and without ego, attains peace.',
      translationHi:
          'जो सब कामनाओं को त्यागकर स्पृहारहित होकर विचरता है, जो ममता और अहंकार से रहित है, वही शांति प्राप्त करता है।',
      applicationEn:
          'The two words worth sitting with are "mine" and ego. Most of what keeps you awake is not the event itself but the claim attached to it — my reputation, my plan, my outcome. Loosen the claim and the same event weighs less.',
      applicationHi:
          'दो शब्दों पर ठहरो: "मेरा" और अहंकार। जो तुम्हें रात भर जगाए रखता है वह अक्सर घटना नहीं, उससे जुड़ा दावा होता है — मेरी प्रतिष्ठा, मेरी योजना, मेरा परिणाम। दावा ढीला करो और वही घटना हल्की हो जाती है।',
      situations: [
        GitaSituation.peace,
        GitaSituation.attachment,
        GitaSituation.anxiety,
      ],
    ),

    // ─────────────────────── beginning again ───────────────────────
    GitaVerse(
      chapter: 6,
      verse: 40,
      sanskrit:
          'पार्थ नैवेह नामुत्र विनाशस्तस्य विद्यते।\nन हि कल्याणकृत्कश्चिद्दुर्गतिं तात गच्छति॥',
      transliteration:
          'pārtha naiveha nāmutra vināśas tasya vidyate\nna hi kalyāṇa-kṛt kaścid durgatiṁ tāta gacchati',
      translationEn:
          'O Partha, one who does good is never destroyed, here or hereafter. No one who does good ever comes to a bad end.',
      translationHi:
          'हे पार्थ, शुभ कर्म करने वाले का न इस लोक में नाश होता है, न परलोक में। हे तात, कल्याण करने वाला कभी दुर्गति को प्राप्त नहीं होता।',
      applicationEn:
          'Arjuna has just asked what happens to someone who tries sincerely and still fails. The answer is that sincere effort is never wasted, even when it does not finish. If you fell off the practice for a month, nothing you built before that was deleted.',
      applicationHi:
          'अर्जुन ने अभी पूछा था कि उसका क्या होता है जो सच्चे मन से प्रयास करके भी असफल रहे। उत्तर यह है कि सच्चा प्रयास कभी व्यर्थ नहीं जाता, भले पूरा न हो। अगर तुम एक महीने के लिए अभ्यास से हट गए, तो उससे पहले जो बनाया था वह मिटा नहीं।',
      situations: [
        GitaSituation.growth,
        GitaSituation.selfDoubt,
        GitaSituation.purpose,
      ],
    ),
    GitaVerse(
      chapter: 3,
      verse: 8,
      sanskrit:
          'नियतं कुरु कर्म त्वं कर्म ज्यायो ह्यकर्मणः।\nशरीरयात्रापि च ते न प्रसिद्ध्येदकर्मणः॥',
      transliteration:
          'niyataṁ kuru karma tvaṁ karma jyāyo hy akarmaṇaḥ\nśarīra-yātrāpi ca te na prasiddhyed akarmaṇaḥ',
      translationEn:
          'Perform your prescribed duty, for action is better than inaction. Even the maintenance of your body would not be possible without action.',
      translationHi:
          'तुम अपना नियत कर्म करो, क्योंकि अकर्म से कर्म श्रेष्ठ है। कर्म न करने से तो तुम्हारे शरीर का निर्वाह भी संभव नहीं होगा।',
      applicationEn:
          'Waiting to feel motivated is itself a decision, and it is the worse one. On the days you have no clarity about the big questions, do the small assigned thing anyway. Clarity tends to arrive during the work, not before it.',
      applicationHi:
          'प्रेरणा महसूस होने का इंतज़ार करना भी एक फैसला है, और वह बुरा फैसला है। जिन दिनों बड़े सवालों पर स्पष्टता न हो, उन दिनों भी छोटा नियत काम कर लो। स्पष्टता अक्सर काम के दौरान आती है, उससे पहले नहीं।',
      situations: [
        GitaSituation.career,
        GitaSituation.purpose,
        GitaSituation.growth,
      ],
    ),
    GitaVerse(
      chapter: 4,
      verse: 38,
      sanskrit:
          'न हि ज्ञानेन सदृशं पवित्रमिह विद्यते।\nतत्स्वयं योगसंसिद्धः कालेनात्मनि विन्दति॥',
      transliteration:
          'na hi jñānena sadṛśaṁ pavitram iha vidyate\ntat svayaṁ yoga-saṁsiddhaḥ kālenātmani vindati',
      translationEn:
          'There is nothing in this world as purifying as knowledge. One perfected in yoga finds it within the self in due course of time.',
      translationHi:
          'इस संसार में ज्ञान के समान पवित्र कुछ भी नहीं है। योग में सिद्ध हुआ मनुष्य समय आने पर उसे स्वयं अपने भीतर पा लेता है।',
      applicationEn:
          '"In due course of time" is doing a lot of work in that sentence. Understanding does not arrive on the day you decide you want it. It accumulates quietly and then one ordinary morning something you have read fifty times finally lands.',
      applicationHi:
          '"समय आने पर" — इस वाक्य में यही सबसे भारी शब्द हैं। समझ उस दिन नहीं आती जिस दिन तुम चाहते हो। वह चुपचाप जमा होती है और फिर किसी साधारण सुबह वह बात, जो तुमने पचास बार पढ़ी है, अचानक भीतर उतर जाती है।',
      situations: [GitaSituation.growth, GitaSituation.purpose],
    ),
    GitaVerse(
      chapter: 9,
      verse: 22,
      sanskrit:
          'अनन्याश्चिन्तयन्तो मां ये जनाः पर्युपासते।\nतेषां नित्याभियुक्तानां योगक्षेमं वहाम्यहम्॥',
      transliteration:
          'ananyāś cintayanto māṁ ye janāḥ paryupāsate\nteṣāṁ nityābhiyuktānāṁ yoga-kṣemaṁ vahāmy aham',
      translationEn:
          'To those who worship Me with single-minded devotion, ever steadfast, I carry what they lack and preserve what they have.',
      translationHi:
          'जो अनन्य भाव से मेरा चिंतन करते हुए मेरी उपासना करते हैं, उन नित्ययुक्त भक्तों का योगक्षेम मैं स्वयं वहन करता हूँ।',
      applicationEn:
          'For the nights when planning has stopped helping and you are simply tired. Some part of the load is not yours to carry tonight. Put it down and pick it up in the morning if it is still there.',
      applicationHi:
          'उन रातों के लिए जब योजना बनाना काम नहीं आ रहा और तुम बस थक चुके हो। बोझ का कुछ हिस्सा आज रात तुम्हारा उठाने को नहीं है। उसे रख दो, और सुबह अगर वह अब भी हो तो उठा लेना।',
      situations: [
        GitaSituation.anxiety,
        GitaSituation.fear,
        GitaSituation.outOfControl,
      ],
    ),
  ];

  static List<GitaVerse> forSituation(GitaSituation? s) =>
      s == null ? verses : verses.where((v) => v.situations.contains(s)).toList();

  /// Situations that actually have verses, so the filter never offers an empty
  /// result.
  static List<GitaSituation> get availableSituations => GitaSituation.values
      .where((s) => verses.any((v) => v.situations.contains(s)))
      .toList();

  static int countFor(GitaSituation s) =>
      verses.where((v) => v.situations.contains(s)).length;
}
