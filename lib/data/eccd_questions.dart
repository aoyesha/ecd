enum EccdLanguage { english, tagalog }

class EccdQuestions {
  static const List<String> domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  static EccdLanguage fromLabel(String label) {
    return label.toLowerCase().contains('tag')
        ? EccdLanguage.tagalog
        : EccdLanguage.english;
  }

  static List<String> get(String domain, EccdLanguage lang) {
    final d = domain.trim();
    if (d == 'Self Help') {
      final sections = selfHelpSections(lang);
      return [
        ...selfHelpCore(lang),
        ...sections['Dressing']!,
        ...sections['Toilet']!,
      ];
    }
    if (lang == EccdLanguage.english) {
      return _english[d] ?? const [];
    }
    return _tagalog[d] ?? const [];
  }

  static Map<String, List<String>> selfHelpSections(EccdLanguage lang) {
    if (lang == EccdLanguage.english) {
      return {
        'Dressing': _english['Dressing'] ?? const [],
        'Toilet': _english['Toilet'] ?? const [],
      };
    }
    return {
      'Dressing': _tagalog['Dressing'] ?? const [],
      'Toilet': _tagalog['Toilet'] ?? const [],
    };
  }

  static List<String> selfHelpCore(EccdLanguage lang) {
    if (lang == EccdLanguage.english) {
      return _english['Self Help'] ?? const [];
    }
    return _tagalog['Self Help'] ?? const [];
  }

  static const Map<String, List<String>> _tagalog = {
    'Gross Motor': [
      'Nakaaakyat sa mga silya/upuan',
      'Nakalalakad ng paurong.',
      'Nakatatakbo  nang hindi nadadapa',
      'Nakabababa  ng hagdan habang hawak ng tagapag-alaga ang isang kamay',
      'Nakaaakyat  ng hagdan na salitan ang mga paa sa bawat baitang habang humahawak sa gabay ng hagdan',
      'Nakaaakyat ng hagdan na salitan ang mga paa na hindi humahawak sa gabay ng hagdan',
      'Nakabababa ng hagdan na salitan ang mga paa na hindi na humahawak sa gabay ng hagdan.',
      'Naigagalaw ang mga bahagi ng katawan kapag inuutusan',
      'Nakatatalon',
      'Nakahahagis ng bola paitaas na may direksyon.',
      'Nakalulundag ng 1-3 beses gamit ang mas gustong paa.',
      'Nakatatalon at nakakaikot',
      'Nakasasayaw/ nakasusunod sa mga hakbang sa sayaw, grupong gawain ukol sa kilos at galaw.',
    ],
    'Fine Motor': [
      'Nakagagamit ng lahat na daliri sa pagdampot ng bagay/pagkain na nakalagay sa mesa',
      'Nakakukuha ng mga bagay gamit ang hinlalaki at hintuturo.',
      'Naipakikita ang partikular na kamay na mas nais gamitin',
      'Nailalagay/Natatanggal ang maliit na bagay mula sa lalagyan.',
      'Nakahahawak ng krayola gamit ang nakasarang palad.',
      'Nakatatanggal ng takip ng bote/lalagyan, Nakaaalis ng balot ng pagkain',
      'Nakagagawa ng mga guhit-guhit.',
      'Nakaguguhit ng patayo at pahalang na marka.',
      'Nakaguguhit ng hugis bilog.',
      'Nakaguguhit ng larawan ng tao (ulo, mata, katawan, braso, kamay, hita, paa).',
      'Nakaguguhit ng bahay gamit ang iba\'t-ibang uri ng hugis (parisukat, tatsulok)',
    ],
    'Self Help': [
      'Pinapakain ang sarili ng mga pagkain tulad ng biskwit at tinapay (finger food)',
      'Pinapakain ang sarili ng ulam at kanin gamit ang mga daliri ngunit may natatapong pagkain',
      'Pinapakain ang sarili gamit ang kutsara ngunit may natatapong pagkain',
      'Pinapakain ang sarili ng ulam at kanin gamit ang mga daliri na walang natatapong pagkain',
      'Pinapakain ang sarili gamit ang kutsara ngunit walang natatapong pagkain',
      'Tumutulong sa paghawak ng baso/tasa sa pag-inom',
      'Umiinom sa baso ngunit may natatapon',
      'Umiinom sa baso na walang umaalalay',
      'Kumukuha ng inumin ng mag-isa',
      'Kumakaing hindi na kailangang subuan pa',
      'Binubuhos ang tubig (o anumang likido) mula sa pitsel na walang natatapon',
      'Naghahanda ng sariling pagkain/meryenda',
      'Naghahanda ng pagkain para sa nakakabatang kapatid/ibang miyembro ng pamilya kung walang matanda sa bahay',
    ],
    'Dressing': [
      'Nakikipagtulungan kung bibihisan (hal., itinataas ang mga kamay/paa)',
      'Hinuhubad ang shorts na may garter',
      'Hinuhubad ang sando',
      'Binibihisan ang sarili na walang tumutulong, maliban sa pagbubutones at pagtatali',
      'Binibihisan ang sarili na walang tumutulong, kasama na ang  pagbubutones at pagtatali',
    ],
    'Toilet': [
      'Ipinakita o ipinahiwatig na naihi o nadumi sa shorts',
      'Pinapaalam sa tagapagalaga ang pangangailangang umihi o dumumi upang makapunta sa tamang lugar (hal., banyo, CR)',
      'Pumupunta sa tamang lugar upang umihi o dumumi ngunit paminsan-minsan ay may pagkakataong hindi mapigilang maihi o madumi sa shorts',
      'Matagumpay na pumupunta sa tamang lugar upang umihi o dumumi',
      'Pinupunasan ang sarili pagkatapos dumumi',
      'Nakikipagtulungan kung pinapaliguan (hal., kinukuskos ang mga braso)',
      'Nakapaghuhugas at nakapagpupunas ng mga kamay nang walang tumutulong.',
      'Nakapaghihilamos  nang walang tumutulong.',
      'Nakapaliligo nang walang tumutulong.',
    ],
    'Receptive Language': [
      'Tinuturo ang mga kapamilya o pamilyar na bagay kapag ipinaturo',
      'Tinuturo ang 5 parte ng katawan kung inuutusan',
      'Tinuturo ang 5 napangalanang larawan ng mga bagay',
      'Sumusunod sa isang lebel na utos na may simpleng pang-ukol (hal., sa ibabaw, sa ilalim)',
      'Sumusunod sa dalawang lebel na utos na may simpleng pang-ukol',
    ],
    'Expressive Language': [
      'Gumagamit ng 5-20 nakikilalang salita',
      'Gumagamit ng panghalip (hal., ako akin)',
      'Gumagamit ng 2-3 kombinasyon ng pandiwa-pantangi (verb-noun combinations) [hal., hingi pera]',
      'Napapangalanan ang mga bagay na nakikita sa larawan (4)',
      'Nagsasalita sa tamang pangungusap na may 2-3 salita',
      'Nagtatanong ng ano',
      'Nagtatanong ng sino at bakit',
      'Kinukuwento ang mga katatapos na karanasan (kapag tinanong/diniktahan) na naayon sa pagkakasunod-sunod ng pangyayari gamit ang mga salitang tumutukoy sa pangnakaraan (past tense)',
    ],
    'Cognitive': [
      'Tinitingnan ang direksyon ng nahuhulog na bagay',
      'Hinahanap ang mga bagay na bahagyang nakatago',
      'Ginagaya ang mga kilos na kakakita pa lamang',
      'Binibigay ang bagay ngunit hindi ito binibitiwan',
      'Hinahanap ang mga bagay na lubusang nakatago',
      'Naglalaro ng kunwa-kunwarian',
      'Tinutugma ang mga bagay',
      'Tinutugma ang 2-3 kulay',
      'Tinutugma ang mga larawan',
      'Nakikilala ang magkakapareho at magkakaibang hugis',
      'Inaayos ang mga bagay ayon sa 2 katangian (hal., laki at kulay)',
      'Inaayos ang mga bagay mula sa pinakamaliit hanggang sa pinakamalaki',
      'Pinapangalan ang 4-6 na kulay',
      'Gumuguhit/ginagaya ang isang disenyo',
      'Pinapangalanan ang 3 hayop o gulay kapag tinanong',
      'Sinasabi ang mga gamit ng mga bagay sa bahay',
      'Nakakabuo ng isang simpleng puzzle',
      'Naiintindihan ang magkakasalungat na mga salita sa pamamagitan ng pagkumpleto ng pangungusap (hal., Ang aso ay malaki, ang daga ay ___ )',
      'Nasasabi kung ano ang mali sa larawan (hal., Ano ang mali sa larawan?)',
      'Tinuturo ang kaliwa at kanang bahagi ng katawan',
      'Tinutugma ang malalaki at maliliit na mga titik',
    ],
    'Social Emotional': [
      'Natutuwang nanonood ng mga ginagawa ng mga tao o hayop sa malapit na lugar mapalagay',
      'Lumalapit sa mga hindi kakilala ngunit sa una ay maaaring maging mahiyain o hindi',
      'Naglalarong mag-isa ngunit gustong malapit sa mga pamilyar na nakatatanda o kapatid',
      'Tumatawa/tumitili nang malakas sa paglalaro',
      'Naglalaro ng \"bulaga\"',
      'Pinapagulong ang bola sa kalaro o tagapag-alaga',
      'Niyayakap ang mga laruan',
      'Nagpapakita ng respeto sa nakataanda gamit ang \"Nang\", \"Nong\", \"Opo\", \"Po\" (o anumang katumbas nito) sa halip na kanilang unang pangalan',
      'Pinahihiram ang sariling laruan sa iba',
      'Ginagaya ang mga ginagawa ng mga nakatatanda (hal., pagluluto, paghuhugas)',
      'Nakatutukoy ang nararamdaman ng iba.',
      'Gumagamit ng mga kilos na nararapat sa kultura na hindi na hinihiling/dinidiktahan (hal., pagmamano, paghalik)',
      'Inaalo/inaaliw ang mga kalaro o kapatid na may problema',
      'Nagpupursige kung may problema o hadlang sa kanyang gusto',
      'Tumutulong sa mga gawaing pambahay (hal., Nagpupunas ng mesa, pagdidilig ng mga halaman)',
      'Interesado sa kaniyang kapaligiran ngunit alam kung kailan kailangang huminto sa pagtatanong',
      'Marunong maghintay (hal., sa paghuhugas ng kamay, sa pagkuha ng pagkain)',
      'Nakapaghihingi ng pahintulot  na magamit ang laruan na nilalaro pa ng ibang bata.',
      'Binabantayan ang mga pag-aari ng may determinasyon',
      'Naglalaro ng maayos sa mga pang-grupong laro (hal., hindi nandadaya para manalo)',
      'Naikukuwento ang mga mabigat na nararamdaman (hal., galit, lungkot)',
      'Tinatanggap ang isang kasunduang ginawa ng tagapag-alaga (hal., linisin muna ang kuwarto bago maglaro sa labas)',
      'Responsableng nagbabantay sa mga nakababatang kapatid/ ibang miyembro ng pamilya',
      'Nakikipagtulungan sa mga nakatatanda at nakababata sa anumang sitwasyon upang maiwasan ang bangayan/alitan',
    ],
  };

  static const Map<String, List<String>> _english = {
    'Gross Motor': [
      'Climbs on chair or other elevated piece of furniture like a bed without help',
      'Walks backwards',
      'Runs without tripping or falling',
      'Walks downstairs, 2 feet on each step, with one hand held',
      'Walks upstairs holding handrail, 2 feet on each step',
      'Walks upstairs with alternate feet without holding handrail',
      'Walks downstairs with alternate feet without holding handrail',
      'Moves body part as directed',
      'Jumps up',
      'Throws ball overhead with direction',
      'Hops 1 to 3 steps on preferred foot',
      'Jumps and turns',
      'Dances patterns / joins group movement activities',
    ],
    'Fine Motor': [
      'Uses all 5 fingers to get food/toys placed on flat surface',
      'Picks up objects with thumb and index finger',
      'Displays a definite hand preference',
      'Puts small objects in/out of containers',
      'Holds crayon with all the fingers of his hand making a fist (i.e., palmar grasp)',
      'Unscrews lid of container or unwraps food',
      'Scribbles spontaneously',
      'Scribbles vertical and horizontal lines',
      'Draws circle purposely',
      'Draws a human figure (head, eyes, trunk, arms, hands/ fingers)',
      'Draws a house using geometric forms',
    ],
    'Self Help': [
      'Feeds self with finger food (e.g. biscuits, bread) using fingers',
      'Feeds self using fingers to eat rice/ viands with spillage',
      'Feeds self using spoon with spillage',
      'Feeds self using fingers without spillage',
      'Feeds self using spoon without spillage',
      'Helps hold cup for drinking',
      'Drinks from cup with spillage',
      'Drinks from cup unassisted',
      'Gets drink for self unassisted',
      'Eats without need for spoon feeding during any meal',
      'Pours from pitcher without spillage',
      'Prepares own food/ snack',
      'Prepares meals for younger siblings/ family members',
    ],
    'Dressing': [
      'Participates when being dressed (e.g. raises arms or lifts leg)',
      'Pulls down gartered short pants',
      'Removes sando',
      'Dresses without assistance except for buttoning and tying',
      'Dresses without assistance including buttoning and tying',
    ],
    'Toilet': [
      'Informs the adult only after he has already urinated (peed) or moved his bowels (poohed) in his underpants',
      'Informs adult of need to urinate (pee) or move bowels (pooh- pooh) so he can be brought to a designated place (e.g. comfort room)',
      'Goes to the designated place to urinate (pee) or move bowels (pooh) but sometimes still does this in his underpants',
      'Goes to the designated place to urinate (pee) or move bowels (pooh) and never does this is his underpants anymore',
      'Wipes/Cleans self after a bowel movement (pooh)',
      'Participates when bathing (e.g. rubbing arms with soap)',
      'Washes and dries hands without any help',
      'Washes face without any help',
      'Bathes without any help',
    ],
    'Receptive Language': [
      'Points to family member when asked to do so',
      'Points to 5 body parts on himself when asked to do so',
      'Points to 5 named pictured objects when asked to do so',
      'Follows one-step instructions that include simple prepositions (e.g., in, on, under, etc.)',
      'Follows 2-step instructions that include simple prepositions',
    ],
    'Expressive Language': [
      'Uses 5 to 20 recognizable words',
      'Uses pronouns (e.g. I, me, ako, akin)',
      'Uses 2 to 3 words verb-noun combinations (e.g. hingi gatas)',
      'Names objects in pictures',
      'Speaks in grammatically correct 2-3 word sentences',
      'Asks \"what\" questions',
      'Asks \"who\" and \"why\" questions',
      'Gives account of recent experiences (with prompting) in order of occurrence using past tense',
    ],
    'Cognitive': [
      'Looks at direction of fallen object',
      'Looks for a partially hidden objects',
      'Imitates behavior just seen a few minutes earlier',
      'Offers on object but may not release it',
      'Looks for completely hidden object',
      'Exhibits simple \"pretend\" play (feeds, puts doll to sleep)',
      'Matches objects',
      'Matches 2 to 3 colors',
      'Matches pictures',
      'Sorts based on shapes',
      'Sorts objects based on 2 attributes (e.g., size and color)',
      'Arranges objects according to size from smallest to biggest',
      'Names 4 to 6 colors',
      'Copies shapes',
      'Names 3 animals or vegetables when asked',
      'States what common household items are used for',
      'Can assemble simple puzzles',
      'Demonstrates an understanding of opposites by completing a statement (e.g., \"A dog is big, a mouse is ________\")',
      'Can state what is silly or wrong with pictures (e.g. What is wrong in this image?)',
      'Points to left and right sides of body',
      'Matches upper and lower case letters',
    ],
    'Social Emotional': [
      'Enjoys watching activities of nearby people or animals',
      'Friendly with strangers but initially may show slight anxiety or shyness',
      'Plays alone but likes to be near familiar adults or brothers and sisters',
      'Laughs or squeals aloud in play',
      'Plays peek-a-boo (bulaga)',
      'Rolls ball interactively with caregiver/examiner',
      'Hugs or cuddles toys',
      'Demonstrates respect for elders using terms like \"po\" and \"opo\"',
      'Shares toys with others',
      'Imitates adult activities (e.g., cooking, washing)',
      'Identifies feelings in others',
      'Appropriately uses cultural gestures of greeting without much prompting (e.g., mano, bless, kiss, etc.)',
      'Comforts playmates/ siblings in distress',
      'Persists when faced with a problem or obstacle to his wants',
      'Helps with family chores (e.g., wiping tables, watering plants, etc.)',
      'Curious about environment but knows when to stop asking questions of adults',
      'Waits for his/her turn',
      'Asks permission to play with toy being used by another',
      'Defends possessions with determination',
      'Plays organized group games fairly (e.g., does not cheat in order to win)',
      'Can talk about difficult feelings (e.g., anger, sadness, worry) he experience',
      'Honors a simple bargain with caregiver (e.g., can play outside only after cleaning / finishing his room)',
      'Watches responsibly over younger siblings/family members',
      'Cooperates with adults and peers in group situations to minimize quarrels and conflicts',
    ],
  };
}
