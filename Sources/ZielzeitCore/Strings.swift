import Foundation

/// Every string the app shows, in every supported language.
///
/// One table rather than strings spread through the views, so a line can be
/// checked against its translation without hunting, and so the popover and
/// `--once` cannot word the same thing two ways.
public enum Strings {

    static func pick(
        _ english: String,
        _ german: String,
        _ french: String,
        _ spanish: String,
        _ italian: String
    ) -> String {
        switch AppLanguage.current {
        case .english: return english
        case .german: return german
        case .french: return french
        case .spanish: return spanish
        case .italian: return italian
        }
    }

    // MARK: - Scenarios

    public static var cautious: String { pick("Cautious", "Vorsichtig", "Prudent", "Prudente", "Prudente") }
    public static var moderate: String { pick("Moderate", "Moderat", "Modéré", "Moderado", "Moderato") }
    public static var yourPace: String { pick("Your pace", "Dein Tempo", "Votre rythme", "Tu ritmo", "Il tuo ritmo") }

    // MARK: - Units and small words

    /// Suffix on a monthly amount, e.g. `€380/mo`.
    public static var perMonth: String { pick("/mo", "/Mon.", "/mois", "/mes", "/mese") }
    /// Suffix on an annual rate, e.g. `+5%/yr`.
    public static var perYear: String { pick("/yr", "/Jahr", "/an", "/año", "/anno") }
    public static var never: String { pick("never", "nie", "jamais", "jamás", "mai") }
    public static var reached: String { pick("reached", "erreicht", "atteint", "alcanzado", "raggiunto") }
    public static var reachedCapitalized: String { pick("Reached", "Erreicht", "Atteint", "Alcanzado", "Raggiunto") }

    // MARK: - Market windows

    public static var windowToday: String { pick("today", "heute", "aujourd’hui", "hoy", "oggi") }
    public static var windowTwoDays: String { pick("2 days", "2 Tage", "2 jours", "2 días", "2 giorni") }
    public static var windowThisWeek: String { pick("this week", "diese Woche", "cette semaine", "esta semana", "questa settimana") }
    public static var windowThisMonth: String { pick("this month", "dieser Monat", "ce mois-ci", "este mes", "questo mese") }
    public static var windowThreeMonths: String { pick("3 months", "3 Monate", "3 mois", "3 meses", "3 mesi") }
    public static var windowSixMonths: String { pick("6 months", "6 Monate", "6 mois", "6 meses", "6 mesi") }
    public static var windowPastYear: String { pick("past year", "letztes Jahr", "année écoulée", "último año", "ultimo anno") }
    public static var windowAllTime: String { pick("all time", "gesamt", "depuis le début", "desde el inicio", "dall’inizio") }
    public static var windowLastSession: String { pick("last session", "letzter Schluss", "dernière séance", "última sesión", "ultima seduta") }

    // MARK: - Summary rows

    public static var portfolio: String { pick("Portfolio", "Portfolio", "Portefeuille", "Cartera", "Portafoglio") }
    public static var saving: String { pick("Saving", "Sparrate", "Épargne", "Ahorro", "Risparmio") }
    /// "Vorjahr" rather than "Letztes Jahr", which is exactly as wide as its own
    /// column in the text report and would leave the value one space out of line
    /// with the rows above it.
    public static var pastYear: String { pick("Past year", "Vorjahr", "Année passée", "Último año", "Ultimo anno") }

    public static func savingsPlans(_ count: Int) -> String {
        switch AppLanguage.current {
        case .english: return "\(count) \(count == 1 ? "plan" : "plans")"
        case .german: return "\(count) \(count == 1 ? "Plan" : "Pläne")"
        case .french: return "\(count) \(count == 1 ? "plan" : "plans")"
        case .spanish: return "\(count) \(count == 1 ? "plan" : "planes")"
        case .italian: return "\(count) \(count == 1 ? "piano" : "piani")"
        }
    }

    // MARK: - Rows and sections

    public static var notEnoughHistory: String { pick("not enough history", "zu wenig Historie", "historique insuffisant", "historial insuficiente", "storico insufficiente") }
    public static var neverAtThisPace: String { pick("never at this pace", "nie in diesem Tempo", "jamais à ce rythme", "nunca a este ritmo", "mai a questo ritmo") }
    public static var nothingGrowthGetsThere: String {
        pick("nothing — growth alone gets there", "nichts — Wachstum allein reicht", "rien — la croissance suffit", "nada — el crecimiento basta", "nulla — basta la crescita")
    }
    public static var versusNow: String { pick("vs now", "ggü. heute", "vs maintenant", "vs ahora", "vs ora") }

    public static func endOf(_ year: Int) -> String {
        pick("end of \(year)", "Ende \(year)", "fin \(year)", "fin de \(year)", "fine \(year)")
    }

    public static func whatIfHeading(rate: String) -> String {
        pick("If I saved more (at \(rate))", "Wenn ich mehr spare (bei \(rate))", "Si j’épargnais plus (à \(rate))", "Si ahorrara más (al \(rate))", "Se risparmiassi di più (al \(rate))")
    }

    public static var marketHeading: String { pick("Market", "Markt", "Marché", "Mercado", "Mercato") }
    public static var projectionsHeading: String { pick("Projections", "Prognosen", "Projections", "Proyecciones", "Proiezioni") }
    public static var todaysMoneyHeading: String { pick("In today's money", "In heutigem Geld", "En valeur actuelle", "En dinero de hoy", "In denaro di oggi") }
    public static var toReachItByHeading: String { pick("To reach it by", "Erreichen bis", "Pour l’atteindre d’ici", "Para alcanzarlo en", "Per raggiungerlo entro") }

    public static func todaysMoneyLine(goal: String, year: Int, real: String, inflation: String) -> String {
        pick(
            "\(goal) in \(year) ≈ \(real)  (at \(inflation) inflation)",
            "\(goal) in \(year) ≈ \(real)  (bei \(inflation) Inflation)",
            "\(goal) en \(year) ≈ \(real)  (avec \(inflation) d’inflation)",
            "\(goal) en \(year) ≈ \(real)  (con \(inflation) de inflación)",
            "\(goal) nel \(year) ≈ \(real)  (con inflazione al \(inflation))"
        )
    }

    // MARK: - Disclaimer

    public static var disclaimerHeadline: String {
        pick("Projections, not predictions", "Prognosen, keine Vorhersagen", "Des projections, pas des prédictions", "Proyecciones, no predicciones", "Proiezioni, non previsioni")
    }
    public static var notAdvice: String { pick("Not financial advice.", "Keine Finanzberatung.", "Ceci n’est pas un conseil financier.", "No es asesoramiento financiero.", "Non è una consulenza finanziaria.") }

    public static func assumesRate(_ rate: String) -> String {
        pick(
            "Assumes \(rate) every year, from one trailing year.",
            "Nimmt \(rate) pro Jahr an, aus einem Jahr Historie.",
            "Suppose \(rate) par an, d’après les 12 derniers mois.",
            "Supone un \(rate) anual, según los últimos 12 meses.",
            "Presuppone il \(rate) annuo, dagli ultimi 12 mesi."
        )
    }
    public static var paceAssumesDeposits: String {
        pick(
            "Pace assumes deposits ran at today's rate all year.",
            "Tempo unterstellt die heutige Sparrate für das Jahr.",
            "Le rythme suppose le taux de versement actuel toute l’année.",
            "El ritmo supone el ahorro actual durante todo el año.",
            "Il ritmo presume il risparmio attuale per tutto l’anno."
        )
    }
    public static func underAYearOfHistory(_ rate: String) -> String {
        pick(
            "Under a year of history — assumes \(rate), not your own pace.",
            "Unter einem Jahr Historie — nimmt \(rate) an, nicht dein Tempo.",
            "Moins d’un an d’historique — suppose \(rate), pas votre rythme.",
            "Menos de un año de historial: supone \(rate), no tu ritmo.",
            "Meno di un anno di storico: presume \(rate), non il tuo ritmo."
        )
    }
    public static var compoundsSmoothly: String {
        pick("Compounds smoothly. Real returns don't.", "Rechnet mit glattem Zins. Echte Renditen nicht.", "Capitalisation régulière. Les rendements réels ne le sont pas.", "Capitalización uniforme. La rentabilidad real no lo es.", "Capitalizzazione regolare. I rendimenti reali non lo sono.")
    }
    public static func assumesContribution(_ amount: String, stepUp: String?) -> String {
        var line = pick("Assumes \(amount)\(perMonth)", "Nimmt \(amount)\(perMonth) an", "Suppose \(amount)\(perMonth)", "Supone \(amount)\(perMonth)", "Presuppone \(amount)\(perMonth)")
        if let stepUp {
            line += pick(", rising \(stepUp)\(perYear)", ", +\(stepUp)\(perYear)", ", +\(stepUp)\(perYear)", ", +\(stepUp)\(perYear)", ", +\(stepUp)\(perYear)")
        }
        line += pick(", never paused.", ", nie pausiert.", ", sans interruption.", ", sin interrupciones.", ", senza interruzioni.")
        return line
    }
    public static var stepUpDateGuessed: String {
        pick(
            "Step-up date is guessed; Scalable doesn't publish it.",
            "Erhöhungsdatum geschätzt; Scalable nennt es nicht.",
            "Date d’augmentation estimée ; Scalable ne la publie pas.",
            "Fecha de aumento estimada; Scalable no la publica.",
            "Data dell’aumento stimata; Scalable non la pubblica."
        )
    }
    public static func beforeTaxWithInflation(_ rate: String) -> String {
        pick(
            "Before tax; today's money assumes \(rate) inflation.",
            "Vor Steuern; heutiges Geld bei \(rate) Inflation.",
            "Avant impôts ; valeur actuelle avec \(rate) d’inflation.",
            "Antes de impuestos; dinero actual con \(rate) de inflación.",
            "Al lordo delle imposte; denaro odierno con inflazione al \(rate)."
        )
    }
    public static var beforeTaxAndInflation: String {
        pick("Before tax and inflation.", "Vor Steuern und Inflation.", "Avant impôts et inflation.", "Antes de impuestos e inflación.", "Al lordo di imposte e inflazione.")
    }

    // MARK: - Errors

    public static func cliNotFound(path: String) -> String {
        pick("Scalable CLI not found at \(path)", "Scalable CLI nicht gefunden unter \(path)", "CLI Scalable introuvable à \(path)", "No se encontró la CLI de Scalable en \(path)", "CLI di Scalable non trovata in \(path)")
    }
    public static var cliTimedOut: String {
        pick("Scalable CLI timed out", "Zeitüberschreitung beim Scalable CLI", "Délai d’attente de la CLI Scalable dépassé", "La CLI de Scalable agotó el tiempo de espera", "Timeout della CLI di Scalable")
    }
    public static var notLoggedIn: String {
        pick(
            "Not logged in — run `sc login` in a terminal",
            "Nicht angemeldet — führe `sc login` im Terminal aus",
            "Non connecté — exécutez `sc login` dans un terminal",
            "Sesión no iniciada: ejecuta `sc login` en un terminal",
            "Accesso non effettuato: esegui `sc login` nel Terminale"
        )
    }
    public static func unexpectedResponse(command: String) -> String {
        pick("Unexpected response from `sc \(command)`", "Unerwartete Antwort von `sc \(command)`", "Réponse inattendue de `sc \(command)`", "Respuesta inesperada de `sc \(command)`", "Risposta imprevista da `sc \(command)`")
    }

    // MARK: - Setup

    public static var enableBeforeSigningIn: String {
        pick(
            "Turn it on before you sign in — a login started first fails with an authentication error that never mentions this switch.",
            "Aktiviere ihn vor der Anmeldung — eine vorher gestartete Anmeldung scheitert mit einem Authentifizierungsfehler, der diesen Schalter nie erwähnt.",
            "Activez-le avant de vous connecter — une connexion lancée avant échoue avec une erreur d’authentification qui ne mentionne jamais ce réglage.",
            "Actívalo antes de iniciar sesión: al revés, el inicio de sesión falla con un error de autenticación que nunca menciona este ajuste.",
            "Attivalo prima di accedere: al contrario, l’accesso fallisce con un errore di autenticazione che non menziona mai questa impostazione."
        )
    }

    // MARK: - Hero

    public static var goalReached: String { pick("Goal reached", "Ziel erreicht", "Objectif atteint", "Objetivo alcanzado", "Obiettivo raggiunto") }
    public static var projected: String { pick("Projected", "Prognose", "Projection", "Proyección", "Proiezione") }
    public static var done: String { pick("Done", "Geschafft", "Terminé", "Conseguido", "Fatto") }
    public static var notYet: String { pick("Not yet", "Noch nicht", "Pas encore", "Aún no", "Non ancora") }
    public static var notWithin100Years: String {
        pick("Not within 100 years at this pace", "Nicht in 100 Jahren in diesem Tempo", "Pas avant 100 ans à ce rythme", "No en 100 años a este ritmo", "Non entro 100 anni a questo ritmo")
    }

    /// The hero sentence, split so the two figures can be weighted differently
    /// from the words joining them: `In ` + duration + ` you'll have about ` +
    /// amount.
    public static var sentenceIn: String { pick("In ", "In ", "Dans ", "En ", "Tra ") }
    public static var sentenceYouWillHave: String {
        pick(" you'll have about ", " hast du etwa ", " vous aurez environ ", " tendrás unos ", " avrai circa ")
    }

    /// `that's about ` + amount + ` in today's money`. German carries the sense in
    /// the opening words instead, so its suffix is empty.
    public static var thatsAbout: String { pick("that's about ", "das sind heute etwa ", "soit environ ", "equivale a unos ", "equivalgono a circa ") }
    public static var inTodaysMoney: String { pick(" in today's money", "", " en valeur actuelle", " en dinero de hoy", " in denaro di oggi") }

    public static func amountOfGoal(_ total: String, _ goal: String) -> String {
        pick("\(total) of \(goal)", "\(total) von \(goal)", "\(total) sur \(goal)", "\(total) de \(goal)", "\(total) di \(goal)")
    }

    // MARK: - Scenario list

    public static var noHistory: String { pick("no history", "keine Historie", "aucun historique", "sin historial", "nessuno storico") }

    // MARK: - Sliders

    public static var saveMore: String { pick("Save more", "Mehr sparen", "Épargner plus", "Ahorrar más", "Risparmia di più") }
    public static func nowPerMonth(_ amount: String) -> String {
        pick("now \(amount)\(perMonth)", "jetzt \(amount)\(perMonth)", "actuellement \(amount)\(perMonth)", "ahora \(amount)\(perMonth)", "ora \(amount)\(perMonth)")
    }
    public static var reachBy: String { pick("Reach by", "Erreichen bis", "Atteindre d’ici", "Alcanzar en", "Raggiungi entro") }
    public static var noSavingsNeeded: String { pick("no savings needed", "kein Sparen nötig", "aucune épargne requise", "no hace falta ahorrar", "nessun risparmio necessario") }
    public static func morePerMonthThanNow(_ amount: String) -> String {
        pick("\(amount)\(perMonth) more than now", "\(amount)\(perMonth) mehr als jetzt", "\(amount)\(perMonth) de plus", "\(amount)\(perMonth) más que ahora", "\(amount)\(perMonth) in più rispetto a ora")
    }
    public static func lessPerMonthThanNow(_ amount: String) -> String {
        pick("\(amount)\(perMonth) less than now", "\(amount)\(perMonth) weniger als jetzt", "\(amount)\(perMonth) de moins", "\(amount)\(perMonth) menos que ahora", "\(amount)\(perMonth) in meno rispetto a ora")
    }
    public static var toStart: String { pick("· to start", "· zu Beginn", "· pour commencer", "· para empezar", "· per iniziare") }

    // MARK: - Goal editor

    public static var yourGoal: String { pick("Your goal", "Dein Ziel", "Votre objectif", "Tu objetivo", "Il tuo obiettivo") }
    public static var whatAreYouAimingFor: String { pick("What are you aiming for?", "Was ist dein Ziel?", "Quel est votre objectif ?", "¿Cuál es tu objetivo?", "Qual è il tuo obiettivo?") }
    public static var save: String { pick("Save", "Sichern", "Enregistrer", "Guardar", "Salva") }
    public static var cancel: String { pick("Cancel", "Abbrechen", "Annuler", "Cancelar", "Annulla") }
    public static var goalHintEmpty: String {
        pick("Try 100000, 100.000 or 100k.", "Zum Beispiel 100000, 100.000 oder 100k.", "Essayez 100000, 100.000 ou 100k.", "Prueba 100000, 100.000 o 100k.", "Prova 100000, 100.000 o 100k.")
    }
    public static var goalHintInvalid: String {
        pick("That doesn't look like an amount.", "Das sieht nicht nach einem Betrag aus.", "Ce montant ne semble pas valide.", "Eso no parece una cantidad.", "Questo non sembra un importo.")
    }
    public static func goalHintValid(_ amount: String) -> String {
        pick("Aiming for \(amount).", "Ziel: \(amount).", "Objectif : \(amount).", "Objetivo: \(amount).", "Obiettivo: \(amount).")
    }

    // MARK: - Empty and error states

    public static var setAGoal: String { pick("Set a goal", "Ziel festlegen", "Définir un objectif", "Fija un objetivo", "Imposta un obiettivo") }
    public static var setAGoalMessage: String {
        pick(
            "Zielzeit needs a target amount before it can tell you when you'll reach it.",
            "Zielzeit braucht einen Zielbetrag, bevor es sagen kann, wann du ihn erreichst.",
            "Zielzeit a besoin d’un montant cible avant de pouvoir estimer quand vous l’atteindrez.",
            "Zielzeit necesita una cantidad objetivo para calcular cuándo la alcanzarás.",
            "Zielzeit ha bisogno di un importo obiettivo per stimare quando lo raggiungerai."
        )
    }
    public static var setGoal: String { pick("Set goal", "Ziel festlegen", "Définir l’objectif", "Fijar objetivo", "Imposta obiettivo") }
    public static var setGoalEllipsis: String { pick("Set goal…", "Ziel festlegen…", "Définir l’objectif…", "Fijar objetivo…", "Imposta obiettivo…") }
    public static var cantReadPortfolio: String {
        pick("Can't read your portfolio", "Portfolio nicht lesbar", "Impossible de lire votre portefeuille", "No se puede leer tu cartera", "Impossibile leggere il portafoglio")
    }
    public static var tryAgain: String { pick("Try again", "Erneut versuchen", "Réessayer", "Reintentar", "Riprova") }
    public static var readingPortfolio: String {
        pick("Reading your portfolio…", "Portfolio wird gelesen…", "Lecture de votre portefeuille…", "Leyendo tu cartera…", "Lettura del portafoglio…")
    }

    // MARK: - Footer and menu

    public static func valued(_ stamp: String) -> String { pick("Valued \(stamp)", "Stand \(stamp)", "Valorisé \(stamp)", "Valorado \(stamp)", "Valutato \(stamp)") }
    public static func fetched(_ stamp: String) -> String { pick("Fetched \(stamp)", "Abgerufen \(stamp)", "Récupéré \(stamp)", "Obtenido \(stamp)", "Recuperato \(stamp)") }
    public static func updated(_ stamp: String) -> String { pick("Updated \(stamp)", "Aktualisiert \(stamp)", "Mis à jour \(stamp)", "Actualizado \(stamp)", "Aggiornato \(stamp)") }
    public static func couldNotUpdate(_ reason: String) -> String {
        pick("Couldn't update: \(reason)", "Aktualisierung fehlgeschlagen: \(reason)", "Échec de la mise à jour : \(reason)", "No se pudo actualizar: \(reason)", "Aggiornamento non riuscito: \(reason)")
    }
    public static var refreshNow: String { pick("Refresh now", "Jetzt aktualisieren", "Actualiser", "Actualizar ahora", "Aggiorna ora") }
    public static var launchAtLogin: String { pick("Launch at login", "Beim Anmelden starten", "Ouvrir à la connexion", "Abrir al iniciar sesión", "Avvia al login") }
    public static var quitZielzeit: String { pick("Quit Zielzeit", "Zielzeit beenden", "Quitter Zielzeit", "Salir de Zielzeit", "Esci da Zielzeit") }
    /// `Updates`, not `Aktualisierungen`: `Jetzt aktualisieren` sits one line
    /// above this in the same menu, and the two would read as variants of each
    /// other. The loanword is what a German reader expects on this menu item.
    public static var checkForUpdates: String { pick("Check for updates", "Nach Updates suchen", "Rechercher les mises à jour", "Buscar actualizaciones", "Controlla aggiornamenti") }
    /// Disclosure, not decoration. Updates install silently, so this line is the
    /// only place the app says that it does — and the version is what makes a
    /// report of "I'm on 1.1 and you say 1.3" actionable at all.
    public static func versionLine(_ version: String) -> String {
        pick(
            "Zielzeit \(version) · updates automatically",
            "Zielzeit \(version) · aktualisiert sich automatisch",
            "Zielzeit \(version) · mise à jour automatique",
            "Zielzeit \(version) · se actualiza automáticamente",
            "Zielzeit \(version) · si aggiorna automaticamente"
        )
    }
    /// The only ask the app ever makes of a reader, and it opens a browser rather
    /// than doing anything itself: a star is a write on the reader's own GitHub
    /// account, which nothing here has — or should want — the credentials for.
    ///
    /// `Stern`, not `Star`: unlike `Updates` one line up, the German word is the
    /// one GitHub's own interface uses, so the loanword would be the odd choice
    /// here rather than the expected one.
    public static var starOnGitHub: String {
        pick("Star on GitHub", "Auf GitHub einen Stern geben", "Ajouter une étoile sur GitHub", "Dar una estrella en GitHub", "Metti una stella su GitHub")
    }
    public static var couldNotChangeLoginItem: String {
        pick("Could not change the login item", "Login-Objekt konnte nicht geändert werden", "Impossible de modifier l’ouverture à la connexion", "No se pudo cambiar el inicio automático", "Impossibile modificare l’avvio al login")
    }

    // MARK: - Market chip

    public static func chipHelp(_ window: String) -> String {
        pick(
            "\(window) — click for another period",
            "\(window) — klicken für einen anderen Zeitraum",
            "\(window) — cliquez pour changer de période",
            "\(window) — haz clic para cambiar el período",
            "\(window) — fai clic per cambiare periodo"
        )
    }

    // MARK: - Language menu

    /// Names of the languages themselves come from `AppLanguage.endonym`, so the
    /// list stays readable to someone who has landed in the wrong one.
    public static var language: String { pick("Language", "Sprache", "Langue", "Idioma", "Lingua") }
    public static var systemLanguage: String { pick("System", "System", "Système", "Sistema", "Sistema") }

    // MARK: - Menu bar

    public static var menuBarSetUp: String { pick("Set up", "Einrichten", "Configurer", "Configurar", "Configura") }
    /// Shorter than the popover's button: this sits in the menu bar, where every
    /// character costs width the user did not choose to give up.
    public static var menuBarSetGoal: String { pick("Set goal", "Ziel setzen", "Définir l’objectif", "Fijar objetivo", "Imposta obiettivo") }

    // MARK: - Setup checklist

    public static var connectYourPortfolio: String { pick("Connect your portfolio", "Portfolio verbinden", "Connectez votre portefeuille", "Conecta tu cartera", "Collega il portafoglio") }
    public static var threeStepsToConnect: String { pick("Three steps to connect", "Drei Schritte zum Verbinden", "Trois étapes pour vous connecter", "Tres pasos para conectar", "Tre passaggi per collegarti") }
    public static var almostThere: String { pick("Almost there", "Fast geschafft", "Vous y êtes presque", "Ya casi está", "Ci sei quasi") }
    public static var setupIntro: String {
        pick(
            "Zielzeit reads your portfolio through Scalable Capital's official CLI. Enable CLI access on your account once, then sign in.",
            "Zielzeit liest dein Portfolio über das offizielle CLI von Scalable Capital. Aktiviere einmalig den CLI-Zugriff in deinem Konto und melde dich dann an.",
            "Zielzeit lit votre portefeuille via la CLI officielle de Scalable Capital. Activez une fois l’accès CLI sur votre compte, puis connectez-vous.",
            "Zielzeit lee tu cartera mediante la CLI oficial de Scalable Capital. Activa una vez el acceso de la CLI en tu cuenta y después inicia sesión.",
            "Zielzeit legge il portafoglio tramite la CLI ufficiale di Scalable Capital. Attiva una volta l’accesso CLI sul tuo account, poi accedi."
        )
    }
    public static var installTheCLI: String { pick("Install the Scalable CLI", "Scalable CLI installieren", "Installer la CLI Scalable", "Instala la CLI de Scalable", "Installa la CLI di Scalable") }
    /// The version matters: the step below it describes 1.0's setup, not the
    /// beta's, and an older CLI would send the user looking for a switch it
    /// never consults.
    public static func cliVersionRequirement(_ version: String) -> String {
        pick("Version \(version) or newer.", "Version \(version) oder neuer.", "Version \(version) ou plus récente.", "Versión \(version) o posterior.", "Versione \(version) o successiva.")
    }
    public static var installationInstructions: String {
        pick("Installation instructions", "Installationsanleitung", "Instructions d’installation", "Instrucciones de instalación", "Istruzioni di installazione")
    }
    public static var enableCLIAccess: String { pick("Enable CLI access", "CLI-Zugriff aktivieren", "Activer l’accès CLI", "Activar el acceso de la CLI", "Attiva l’accesso CLI") }
    public static var accessEnabled: String { pick("CLI access enabled", "CLI-Zugriff aktiviert", "Accès CLI activé", "Acceso de la CLI activado", "Accesso CLI attivato") }
    /// The path is Scalable Capital's own, and stays in their words — see
    /// `Onboarding.accessPath`.
    public static func enableAccessExplanation(path: String) -> String {
        pick(
            "Turn on Agentic Investing in your Scalable account: \(path).",
            "Aktiviere Agentic Investing in deinem Scalable-Konto: \(path).",
            "Activez Agentic Investing dans votre compte Scalable : \(path).",
            "Activa Agentic Investing en tu cuenta de Scalable: \(path).",
            "Attiva Agentic Investing nel tuo account Scalable: \(path)."
        )
    }
    public static var openScalable: String { pick("Open Scalable", "Scalable öffnen", "Ouvrir Scalable", "Abrir Scalable", "Apri Scalable") }
    public static var markAccessEnabled: String { pick("I've enabled it", "Ist aktiviert", "C’est activé", "Ya está activado", "L’ho attivato") }
    public static var accessEnabledNote: String {
        pick(
            "Zielzeit can't see this switch, so it takes your word for it. Sign in below.",
            "Zielzeit kann diesen Schalter nicht sehen und verlässt sich auf deine Angabe. Melde dich unten an.",
            "Zielzeit ne peut pas voir ce réglage et vous croit sur parole. Connectez-vous ci-dessous.",
            "Zielzeit no puede ver este ajuste, así que confía en ti. Inicia sesión abajo.",
            "Zielzeit non può vedere questa impostazione e si fida di te. Accedi qui sotto."
        )
    }
    public static var signIn: String { pick("Sign in", "Anmelden", "Se connecter", "Iniciar sesión", "Accedi") }
    public static var signInExplanation: String {
        pick(
            "Run this yourself in Terminal — Zielzeit never handles your credentials. The flag keeps the session read-only.",
            "Führe das selbst im Terminal aus — Zielzeit sieht deine Zugangsdaten nie. Das Flag hält die Sitzung schreibgeschützt.",
            "Exécutez ceci vous-même dans le Terminal — Zielzeit n’accède jamais à vos identifiants. L’option maintient la session en lecture seule.",
            "Ejecuta esto en Terminal: Zielzeit nunca gestiona tus credenciales. La opción mantiene la sesión en modo de solo lectura.",
            "Eseguilo personalmente nel Terminale: Zielzeit non gestisce mai le tue credenziali. L’opzione mantiene la sessione in sola lettura."
        )
    }
    public static var checkAgain: String { pick("Check again", "Erneut prüfen", "Vérifier à nouveau", "Comprobar de nuevo", "Controlla di nuovo") }
    public static var copy: String { pick("Copy", "Kopieren", "Copier", "Copiar", "Copia") }
    public static var openInTerminal: String { pick("Open in Terminal", "Im Terminal öffnen", "Ouvrir dans le Terminal", "Abrir en Terminal", "Apri nel Terminale") }

    // MARK: - Text mode

    public static var noGoalSet: String {
        pick(
            "No goal set. Set one in the app, or pass ZIELZEIT_GOAL=100000.",
            "Kein Ziel gesetzt. Lege eins in der App fest oder setze ZIELZEIT_GOAL=100000.",
            "Aucun objectif défini. Définissez-en un dans l’app ou passez ZIELZEIT_GOAL=100000.",
            "No hay objetivo. Fija uno en la app o usa ZIELZEIT_GOAL=100000.",
            "Nessun obiettivo impostato. Impostalo nell’app o usa ZIELZEIT_GOAL=100000."
        )
    }
    public static func errorPrefix(_ message: String) -> String {
        pick("Error: \(message)", "Fehler: \(message)", "Erreur : \(message)", "Error: \(message)", "Errore: \(message)")
    }
    public static var notConnectedYet: String {
        pick(
            "Zielzeit isn't connected to your portfolio yet.",
            "Zielzeit ist noch nicht mit deinem Portfolio verbunden.",
            "Zielzeit n’est pas encore connecté à votre portefeuille.",
            "Zielzeit aún no está conectado a tu cartera.",
            "Zielzeit non è ancora collegato al portafoglio."
        )
    }
    public static var stepInstallCLI: String {
        pick("1. Install the Scalable CLI:", "1. Scalable CLI installieren:", "1. Installez la CLI Scalable :", "1. Instala la CLI de Scalable:", "1. Installa la CLI di Scalable:")
    }
    public static var stepEnableAccess: String {
        pick(
            "2. Enable CLI access on your Scalable account:",
            "2. CLI-Zugriff in deinem Scalable-Konto aktivieren:",
            "2. Activez l’accès CLI sur votre compte Scalable :",
            "2. Activa el acceso de la CLI en tu cuenta de Scalable:",
            "2. Attiva l’accesso CLI sul tuo account Scalable:"
        )
    }
    public static var stepSignIn: String { pick("3. Sign in:", "3. Anmelden:", "3. Connectez-vous :", "3. Inicia sesión:", "3. Accedi:") }
    public static var ifNotEnabledYet: String {
        pick(
            "If you haven't enabled CLI access yet:",
            "Falls du den CLI-Zugriff noch nicht aktiviert hast:",
            "Si vous n’avez pas encore activé l’accès CLI :",
            "Si aún no has activado el acceso de la CLI:",
            "Se non hai ancora attivato l’accesso CLI:"
        )
    }
    public static var thenSignIn: String { pick("Then sign in:", "Dann anmelden:", "Connectez-vous ensuite :", "Después inicia sesión:", "Poi accedi:") }

    // MARK: - Holdings page

    /// The page's own name, on the button that opens it and in its header.
    ///
    /// "Positionen" rather than "Beteiligungen": it is the word a German broker
    /// statement uses for the lines in a portfolio, and Scalable's own app uses it.
    public static var holdings: String { pick("Holdings", "Positionen", "Positions", "Posiciones", "Posizioni") }
    public static var back: String { pick("Back", "Zurück", "Retour", "Atrás", "Indietro") }

    public static var readingHoldings: String {
        pick("Reading your positions…", "Positionen werden gelesen…", "Lecture de vos positions…", "Leyendo tus posiciones…", "Lettura delle posizioni…")
    }
    public static var cantReadHoldings: String {
        pick("Can't read your positions", "Positionen nicht lesbar", "Impossible de lire vos positions", "No se pueden leer tus posiciones", "Impossibile leggere le posizioni")
    }
    public static var noHoldings: String { pick("No positions", "Keine Positionen", "Aucune position", "Sin posiciones", "Nessuna posizione") }
    public static var noHoldingsMessage: String {
        pick(
            "The broker reports no positions in this portfolio yet.",
            "Der Broker meldet für dieses Portfolio noch keine Positionen.",
            "Le courtier ne signale encore aucune position dans ce portefeuille.",
            "El bróker aún no informa de posiciones en esta cartera.",
            "Il broker non segnala ancora posizioni in questo portafoglio."
        )
    }

    /// Marks figures behind a quote the broker itself flagged as stale.
    public static var quoteOutdated: String {
        pick("Some quotes are stale", "Einige Kurse sind veraltet", "Certains cours sont obsolètes", "Algunas cotizaciones están desactualizadas", "Alcune quotazioni non sono aggiornate")
    }

    // MARK: - Holdings · time contribution

    public static var whatBoughtYouTime: String {
        pick("What bought you time", "Was Zeit gebracht hat", "Ce qui vous a fait gagner du temps", "Lo que te hizo ganar tiempo", "Cosa ti ha fatto guadagnare tempo")
    }

    /// The hero reframes an abstract market gain in the app's own unit: goal time.
    public static var marketGainsInTime: String {
        pick("Market gains, in goal time", "Marktgewinne, in Zielzeit", "Gains du marché, en temps gagné", "Ganancias del mercado, en tiempo hasta el objetivo", "Guadagni di mercato, in tempo sull’obiettivo")
    }
    public static var weeksWord: String { pick("weeks", "Wochen", "semaines", "semanas", "settimane") }
    public static var closerToGoal: String { pick("closer to your goal", "näher an deinem Ziel", "plus près de votre objectif", "más cerca de tu objetivo", "più vicino al tuo obiettivo") }
    public static var fartherFromGoal: String {
        pick("farther from your goal", "weiter von deinem Ziel entfernt", "plus loin de votre objectif", "más lejos de tu objetivo", "più lontano dal tuo obiettivo")
    }

    /// The hero's two labels, under the two years.
    public static var yours: String { pick("yours", "mit Gewinn", "avec gains", "con ganancias", "con guadagni") }
    public static var withoutGains: String { pick("without gains", "ohne Gewinn", "sans gains", "sin ganancias", "senza guadagni") }

    /// Stands in for the second year when the goal is never reached without the
    /// gains, which is a stronger statement than any date.
    public static var withoutGainsNever: String {
        pick("out of reach", "unerreichbar", "hors d’atteinte", "fuera de alcance", "irraggiungibile")
    }

    /// Names the page's one composition mark.
    public static var theWholePortfolio: String {
        pick("What you hold", "Was du hältst", "Ce que vous détenez", "Lo que tienes", "Cosa possiedi")
    }
    public static func positionCount(_ count: Int) -> String {
        pick(
            count == 1 ? "1 position" : "\(count) positions",
            count == 1 ? "1 Position" : "\(count) Positionen",
            count == 1 ? "1 position" : "\(count) positions",
            count == 1 ? "1 posición" : "\(count) posiciones",
            count == 1 ? "1 posizione" : "\(count) posizioni"
        )
    }

    /// The hero when the gains do not move the arrival *year* — the ordinary case,
    /// since a few thousand euros against a six-figure goal is weeks, not years.
    ///
    /// Said plainly rather than dressed up: printing the same year twice with an
    /// arrow between them would claim the gains changed nothing, and inventing month
    /// precision to force a visible difference would claim the projection is sharper
    /// than it is.
    /// Deliberately without the number: the line directly beneath carries the weeks
    /// and the euros, and stating the weeks here too put the same figure twice in
    /// adjacent lines — once as "later", once as "earlier".
    public static var sameYearWithoutGains: String {
        pick("Without your gains, the same year.", "Ohne deine Gewinne dasselbe Jahr.", "Sans vos gains, la même année.", "Sin tus ganancias, el mismo año.", "Senza i tuoi guadagni, lo stesso anno.")
    }

    /// The hero when they do move it.
    public static func withoutGainsYear(_ year: Int) -> String {
        pick("Without your gains: \(year)", "Ohne deine Gewinne: \(year)", "Sans vos gains : \(year)", "Sin tus ganancias: \(year)", "Senza i tuoi guadagni: \(year)")
    }

    /// The hero unit. Weeks rather than months because the numbers are small: a
    /// gain worth 0.4 months reads as nothing, the same gain as two weeks reads as
    /// something.
    public static func weeksEarlier(_ weeks: String) -> String {
        pick("\(weeks) weeks earlier", "\(weeks) Wochen früher", "\(weeks) semaines plus tôt", "\(weeks) semanas antes", "\(weeks) settimane prima")
    }
    public static func weeksLater(_ weeks: String) -> String {
        pick("\(weeks) weeks later", "\(weeks) Wochen später", "\(weeks) semaines plus tard", "\(weeks) semanas después", "\(weeks) settimane dopo")
    }
    public static var weeksAbbreviated: String { pick("wk", "Wo.", "sem.", "sem.", "sett.") }

    /// Says out loud what the hero figure is, so the number is not mistaken for a
    /// return.
    public static func gainsInGoalTime(_ gain: String) -> String {
        pick(
            "Your \(gain) of gains, as arrival date.",
            "Dein Gewinn von \(gain), als Zieldatum.",
            "Vos \(gain) de gains, convertis en date d’arrivée.",
            "Tus \(gain) de ganancias, como fecha de llegada.",
            "I tuoi \(gain) di guadagno, come data di arrivo."
        )
    }

    /// Shown in place of a bar when the goal is not reached without that position.
    public static var withoutItNoArrival: String {
        pick("carries the goal", "trägt das Ziel", "rend l’objectif possible", "hace posible el objetivo", "rende possibile l’obiettivo")
    }

    public static var noArrivalToMove: String {
        pick(
            "No projected arrival to move, so there is no time to attribute.",
            "Ohne Prognose gibt es keine Zeit, die sich zuordnen ließe.",
            "Aucune date prévue à avancer, donc aucun temps à attribuer.",
            "No hay una fecha prevista que mover, así que no hay tiempo que atribuir.",
            "Non c’è una data prevista da anticipare, quindi nessun tempo da attribuire."
        )
    }

    // MARK: - Holdings · cost basis

    public static var yourMoneyAndTheMarkets: String {
        pick("Your money · the market's", "Dein Geld · das des Marktes", "Votre argent · le marché", "Tu dinero · el mercado", "Il tuo denaro · il mercato")
    }
    public static func paidIn(_ amount: String) -> String {
        pick("Paid in \(amount)", "Eingezahlt \(amount)", "Versé \(amount)", "Aportado \(amount)", "Versato \(amount)")
    }
    public static func earned(_ amount: String) -> String {
        pick("Earned \(amount)", "Erwirtschaftet \(amount)", "Gagné \(amount)", "Ganado \(amount)", "Guadagnato \(amount)")
    }
    public static var invested: String { pick("Invested", "Investiert", "Investi", "Invertido", "Investito") }
    public static var marketGain: String { pick("Market gain", "Marktgewinn", "Gain du marché", "Ganancia del mercado", "Guadagno di mercato") }
    public static var totalReturn: String { pick("Return", "Rendite", "Rendement", "Rentabilidad", "Rendimento") }

    // MARK: - Holdings · position impact

    public static var positionImpact: String { pick("Position impact", "Wirkung je Position", "Impact par position", "Impacto por posición", "Impatto per posizione") }
    public static var positionImpactLegend: String {
        pick("share · return · time", "Anteil · Rendite · Zeit", "part · rendement · temps", "peso · rentabilidad · tiempo", "quota · rendimento · tempo")
    }
    public static var ofPortfolio: String { pick("of portfolio", "vom Portfolio", "du portefeuille", "de la cartera", "del portafoglio") }
    public static var worthNoticing: String { pick("Worth noticing", "Auffällig", "À noter", "A destacar", "Da notare") }
    public static func outlierInsight(_ name: String, gap: String, isAhead: Bool) -> String {
        if isAhead {
            return pick(
                "\(name) leads your portfolio by \(gap) percentage points.",
                "\(name) liegt \(gap) Prozentpunkte vor deinem Portfolio.",
                "\(name) devance votre portefeuille de \(gap) points de pourcentage.",
                "\(name) supera tu cartera en \(gap) puntos porcentuales.",
                "\(name) supera il portafoglio di \(gap) punti percentuali."
            )
        }
        return pick(
            "\(name) trails your portfolio by \(gap) percentage points.",
            "\(name) liegt \(gap) Prozentpunkte hinter deinem Portfolio.",
            "\(name) est en retrait de \(gap) points de pourcentage sur votre portefeuille.",
            "\(name) queda \(gap) puntos porcentuales por detrás de tu cartera.",
            "\(name) è indietro di \(gap) punti percentuali rispetto al portafoglio."
        )
    }

    // MARK: - Holdings · since buy

    public static var sinceYouBought: String { pick("Since you bought", "Seit dem Kauf", "Depuis votre achat", "Desde que compraste", "Dal tuo acquisto") }
    public static func portfolioAt(_ percent: String) -> String {
        pick("portfolio \(percent)", "Portfolio \(percent)", "portefeuille \(percent)", "cartera \(percent)", "portafoglio \(percent)")
    }

}
