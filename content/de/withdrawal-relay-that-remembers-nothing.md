---
title: "Die Widerrufs-Weiterleitung, die sich an nichts erinnert: Ein zustandsloser Endpunkt, zwei identische 404-Fehler und eine Bestätigungsmail, die man nicht zurückholen kann"
date: "2026-09-14"
description: "Eine Widerrufs-Funktion auf einem Multi-Merchant-Marktplatz sah nach einem gewöhnlichen 'Bestellung stornieren'-Endpunkt aus. Tatsächlich schreibt sie nirgendwo in eine Datenbank, liefert für zwei völlig unterschiedliche Fehler dieselbe 404-Meldung und verschickt eine Bestätigung, die das System selbst nicht mehr zurücknehmen kann."
tags: ["REST API", "E-Commerce", "Architektur", "Java"]
image: "/withdrawalRelay.jpeg"
featured: true
---

# Die Widerrufs-Weiterleitung, die sich an nichts erinnert: Ein zustandsloser Endpunkt, zwei identische 404-Fehler und eine Bestätigungsmail, die man nicht zurückholen kann

Das Ticket klang nach einer Routineaufgabe: Ein Kunde soll auf einem Multi-Merchant-Marktplatz eine Widerrufserklärung für den Anteil eines einzelnen Händlers an seiner Bestellung einreichen können — das gesetzliche Widerrufsrecht, das EU- und deutsches Verbraucherrecht Privatkunden einräumt (§ 355 BGB). Wie immer bei allem, das "stornieren" oder "widerrufen" im Namen trägt, habe ich zuerst nach dem Datenmodell gesucht. Es gibt keins. Keine fehlende Migration, keine Tabelle, die ich nur noch nicht gefunden hatte — im gesamten System existiert schlicht keine Stelle, an der ein Widerruf gespeichert wird. Der Endpunkt validiert ein Formular, verschickt zwei E-Mails und liefert `200 OK` zurück. Das ist die gesamte Funktion.

Sobald das einmal klar war, ergab der Rest des Designs deutlich mehr Sinn — und die meisten seiner Ecken und Kanten auch.

## Eine Weiterleitung, kein Workflow

Die Plattform führt den Widerruf nicht selbst aus. Sie hat auf diesem Marktplatzmodell keine Befugnis, im Namen eines Händlers zu stornieren oder zu erstatten. Die eigentliche Aufgabe des Endpunkts ist deshalb deutlich schmaler, als der Name vermuten lässt: die Anfrage validieren, dem Kunden den Eingang per E-Mail bestätigen und den zuständigen Händler benachrichtigen, mit der Bitte, innerhalb von 24 Stunden zu reagieren. Was danach passiert — die Position tatsächlich stornieren, eine Retoure abwickeln, den Kunden erstatten — findet komplett außerhalb dieses Systems statt, in der eigenen Software des Händlers.

Dieser Rahmen ist wichtig für eine Neuimplementierung, denn es ist verlockend, das Ganze als Feature einer Bestell-Zustandsmaschine zu bauen — und genau das ist es kategorisch nicht. Kein Bestellobjekt, keine Position, kein Fulfillment-Datensatz ändert sich durch den Aufruf. Näher dran ist ein Kontaktformular mit strenger Validierung und zwei Vorlagen-E-Mails als ein Stornierungs-Workflow.

```text
POST Widerrufserklärung
 |
 v
[Captcha prüfen, falls nötig]
 |
 v
Formular validieren
 |-- ungültig ---------> 400
 v
Bestellung + Teilbestellung
auflösen
 |-- nicht gefunden ---> 404
 v
Privatkunde?
 |-- nein -------------> 403
 v
Bestätigungsmail an Kunden
 |-- Fehler -----------> 500
 v
Händler-Empfänger auflösen
 |
 v
Benachrichtigung an Händler
 |-- Fehler -----------> 500
 v
200 OK
```

Jeder Schritt in diesem Diagramm ist eine Validierung oder eine Benachrichtigung. Keiner davon ist ein Schreibvorgang.

## Die eine Tatsache, die alles Weitere prägt

Bestätigt habe ich das, indem ich die gesamte Codebasis nach irgendetwas durchsucht habe, das einer Widerrufs-Entität ähnelt — keine persistenten Objektdefinitionen, keine Setter auf der Bestellung oder ihren Positionen aus diesem Codepfad, nichts. Der Endpunkt *liest* die Bestellung nur, um herauszufinden, welche Händler-Teilbestellung der Kunde meint; geschrieben wird nie.

Die praktische Konsequenz: Es gibt aus den eigenen Daten dieses Systems keine Möglichkeit, im Nachhinein zu beantworten, "wurde diese Bestellung widerrufen?". Wenn ein Support-Mitarbeiter das wissen muss, liest er Anwendungs-Logs, nicht ein Statusfeld — denn ein Statusfeld existiert nicht. Wer diese Funktion neu implementiert und später eine Antwort auf genau diese Frage braucht — Audit-Trail, Abgleich, egal was —, plant damit einen neuen Scope, keine Übernahme aus dem bestehenden Design. Man sollte nicht automatisch eine `status`-Spalte auf diese Tabelle setzen, nur weil jeder andere "Formular verarbeiten"-Endpunkt im System eine hat.

## Eine Resource-Klasse, die alles macht — größtenteils mit Absicht

Die meisten REST-Endpunkte in dieser Codebasis leiten Validierung und Orchestrierung über eine Service-Schicht. Dieser nicht — die Resource-Klasse selbst übernimmt Formularvalidierung, Bestell-Lookup, Empfänger-Auflösung und E-Mail-Versand, mit explizit deaktiviertem Transaktions-Wrapper, da ohnehin nichts geschrieben wird:

```java
@POST
@Consumes({ MediaType.APPLICATION_JSON })
@Transactional(false)
public Response createWithdrawalNotice(WithdrawalRequestRO request) {
    // 1. Captcha-Prüfung
    // 2. vierstufige Formularvalidierung
    // 3. Bestellung + Händler-Teilbestellung anhand der übermittelten Bestellnummer auflösen
    // 4. nur Privatkunden zulassen
    // 5. Bestätigungsmail an den Kunden
    // 6. Benachrichtigungsmail an den Händler
    // 7. 200 zurückgeben
}
```

Die eine bewusst überentwickelte Ecke ist das Request-DTO. Die Basis-Resource-Klasse der Plattform akzeptiert unbekannte JSON-Felder standardmäßig stillschweigend, statt sie abzulehnen — für einen öffentlichen, nicht authentifizierten Endpunkt genau das falsche Verhalten. Die Lösung ist ein eigener Deserializer, der den JSON-Token-Stream selbst durchläuft und alles außerhalb einer expliziten Allow-List zurückweist:

```java
static final Set<String> ALLOWED_FIELDS = Set.of(
    "merchantOrderNumber", "customerEmail", "salutation",
    "firstName", "lastName", "message"
);
```

Die Formularvalidierung selbst läuft in genau dieser Reihenfolge in vier strengen Stufen: Pflichtfeld-Prüfung (wobei `salutation` nur als "null" behandelt wird, ein leerer String gilt als legitimes "keine Angabe"), HTML-Bereinigung ausschließlich des Freitext-Nachrichtenfelds, eine zweite Leer-Prüfung *nach* der Bereinigung (damit `<script>alert(1)</script>` als fehlend abgelehnt wird statt stillschweigend als leerer Kommentar durchzugehen), und schließlich feldweise Formatprüfungen. Eine dieser Formatprüfungen löst eine Whitelist erlaubter Anreden anhand der Locale der *aktuellen Anfrage* auf, nicht anhand der Standard-Locale der Anwendung — vertauscht man das, werden für jeden Shop mit abweichender Locale gültige Anreden fälschlich abgelehnt.

## Zwei 404-Fehler, eine Nachricht

Die Bestellungsauflösung läuft in zwei Schritten: das Händler-Suffix von der übermittelten Bestellnummer abtrennen, um die übergeordnete Belegnummer zu erhalten, die Bestellung nachschlagen, dann die passende Händler-Teilbestellung darin finden. Beide Fehlerzweige werfen dieselbe Meldung:

```java
if (order == null) {
    throw RestException.builder().notFound()
        .responseMessage("No order found for the given merchant order number").build();
}

MerchantSubOrder subOrder = merchantOrders.stream()
    .filter(mo -> merchantOrderNumber.equals(mo.getMerchantOrderNo()))
    .findFirst()
    .orElseThrow(() -> RestException.builder().notFound()
        .responseMessage("No order found for the given merchant order number").build());
```

```text
Bestellnummer (eingereicht)
 |
 v
Händler-Suffix abtrennen
 |
 v
Übergeordnete Bestellung da?
 |-- nein --------+
 v                |
Teilbestellung    |
passt zum Suffix? |
 |-- nein --------+
 v                v
Weiter            404
                  "No order found
                  for the given
                  merchant order
                  number"
(beide Fälle: dieselbe Meldung)
```

Zwei tatsächlich unterschiedliche Fehler, beide enden im Diagramm bei derselben 404-Meldung. "Die Bestellnummer ist komplett falsch" und "die Bestellung existiert, aber dieses Händler-Suffix passt zu nichts darin" sind zwei verschiedene Probleme mit unterschiedlichen wahrscheinlichen Ursachen — ein Tippfehler gegenüber einem veralteten Link, zum Beispiel —, und ein Support-Mitarbeiter, der eine Logzeile liest, kann sie nicht unterscheiden. Eine Kleinigkeit, aber genau die Art von Mehrdeutigkeit, die aus einem Zwei-Minuten-Ticket ein Zwanzig-Minuten-Ticket macht.

## Die Bestätigungsmail, die man nicht zurückholen kann

Das ist der Punkt, den ich jedem als Erstes nennen würde, der diese Funktion neu baut. Die beiden E-Mails werden nicht atomar verschickt, und ihre Reihenfolge steht nicht im Verhältnis zu ihrer jeweiligen Konsequenz: Zuerst geht die Kundenbestätigung raus, und nur wenn das gelingt, wird überhaupt versucht, den Händler zu benachrichtigen.

```java
sendWithBcc(request.getCustomerEmail(), bcc, sender, locale, clientTemplate, subject);
// Händler-Mail wird nur versucht, wenn die Zeile oben nicht geworfen hat
List<String> recipients = resolveMerchantRecipients(merchantId);
if (recipients.isEmpty()) {
    throw new WithdrawalNotificationException("No recipients found for merchant notification.");
}
sendWithBcc(recipients, bcc, sender, locale, merchantTemplate, subject);
```

Schlägt die Händler-Mail fehl — keine Empfänger auflösbar, oder der Versand selbst scheitert nach mehreren Versuchen —, liefert der Endpunkt `500`. Der Kunde hat zu diesem Zeitpunkt aber bereits eine Bestätigung erhalten, die suggeriert, sein Widerruf sei bearbeitet worden. Es gibt keine kompensierende Nachricht zurück an den Kunden, keinen persistierten Fehlerdatensatz und keine Retry-Queue — die einzige Spur ist eine serverseitige Logzeile. Wer rund um diesen Endpunkt Monitoring aufbaut, muss gezielt nach diesem Fehlerfall in den Logs suchen, denn in den eigenen Daten des Systems taucht er nirgendwo abfragbar auf.

```text
1. Kunde -----> Endpunkt
   Widerruf einreichen
2. Endpunkt --> Kunde
   Bestätigungsmail: OK
   (Kunde glaubt jetzt: wird
    bearbeitet)
3. Endpunkt --> Verzeichnis
   Händler-Empfänger auflösen
4. Verzeichnis --> Endpunkt
   keine Empfänger / Fehler
5. Endpunkt --> Kunde
   500 Internal Error
   !! Nie eine korrigierende
      Nachricht an den Kunden !!
```

Der E-Mail-Versand selbst hat zwar einen Retry — drei Versuche im Abstand von zwei Sekunden, fest im Code verdrahtet statt konfigurierbar —, aber der Retry schützt nur vor vorübergehenden Versandfehlern, nicht vor dem oben beschriebenen Reihenfolgeproblem.

## Empfänger aus Cache, Fallback oder gar nichts

Die Benachrichtigungsadresse des Händlers liegt gar nicht in diesem System; sie wird über einen externen Händlerverzeichnis-Dienst aufgelöst, per OAuth2-Client-Credentials abgerufen und fünf Minuten gecacht, um den Dienst nicht bei jeder Einreichung zu belasten:

```java
List<String> resolveMerchantRecipients(String merchantId) {
    List<String> recipients = merchantId != null
        ? fetchFromMerchantDirectory(merchantId)   // breites catch(Exception) intern
        : new ArrayList<>();
    if (recipients.isEmpty()) {
        recipients = resolveFallbackRecipient(config); // statische Config-Adresse
    }
    return recipients;
}
```

```text
Händler-Empfänger auflösen
 |
 +- Händler-ID fehlt?
 |    ja --> Fallback-Adresse
 |
 +- Verzeichnis-Dienst fragen
 |    Erfolg, nicht leer
 |      --> diese Empfänger
 |    Fehler oder leer
 |      --> Fallback-Adresse
 |
 v
Benachrichtigung senden
(Fallback = statische Config-Adresse)
```

Zwei Dinge sind hier erwähnenswert, falls man etwas Ähnliches baut. Erstens: Jeder Fehler beim Zugriff auf diesen externen Dienst — Timeout, Auth-Fehler, unerwartete Antwort — fällt still auf eine statische Fallback-Adresse zurück, statt die Anfrage hart scheitern zu lassen. Das ist eine vertretbare Entscheidung (lieber landet die Benachrichtigung in einem generischen Support-Postfach als bei niemandem), aber es ist eine Entscheidung — und sollte bewusst getroffen werden, nicht als Nebeneffekt eines zu breiten `catch`. Zweitens: Sind jemals mehrere Adapter-Instanzen für diesen externen Dienst konfiguriert, nimmt der Code einfach die, die aus einer ungeordneten Collection zuerst zurückkommt — mit genau einem konfigurierten Adapter unproblematisch, mit zweien still nicht-deterministisch.

Der Fünf-Minuten-Cache bedeutet: Aktualisiert ein Händler seine Benachrichtigungsadresse, gehen Widerrufe bis zu fünf Minuten lang noch an die alte Adresse. Das sollte man explizit dokumentieren, sobald die Empfänger-Korrektheit während eines Adresswechsels eines Händlers je geschäftskritisch wird.

## Was ich übernommen habe, was ich ändern würde

**Zustandslos per Design ist in Ordnung — solange man das laut sagt.** Nichts hier ist dadurch kaputt, dass keine Persistenz existiert; viele "leite das einfach an jemand anderen weiter"-Funktionen brauchen tatsächlich keine Datenbankzeile. Der Fehler wäre, das bei einer Neuimplementierung so zu bauen, als *gäbe* es irgendwo einen Zustand — oder später eine Datenbank draufzusetzen, ohne vorher zu entscheiden, was Dedup- und Statussemantik überhaupt bedeuten sollen.

**Identische Fehlermeldungen für unterschiedliche Ursachen sparen einem nichts.** Zwei Zweige, zwei Meldungen, fünf zusätzliche Wörter. Kostet beim Schreiben fast nichts und spart später echte Debugging-Zeit.

**Seiteneffekt-Aufrufe danach ordnen, was rückgängig zu machen ist und was nicht.** Lässt sich eine von zwei Aktionen nach erfolgreicher Ausführung nicht mehr zurücknehmen, sollte nicht ausgerechnet die zuerst versucht werden — ohne einen Plan dafür, was passiert, wenn die zweite fehlschlägt. In diesem Fall existiert dieser Plan noch nicht vollständig — eine bekannte Lücke, keine Lücke, die ich hier stillschweigend übergehe.

**Ein stiller Fallback ist eine Design-Entscheidung, kein Sicherheitsnetz.** "Graceful degradieren" ist gute Praxis; "graceful degradieren, ohne dass jemand bewusst entschieden hat, dass genau das passieren soll" ist der Weg dahin, monatelang zu debuggen, warum Benachrichtigungen still in einem generischen Postfach gelandet sind, bevor es jemandem auffällt.

Eine Funktion, die "nur zwei E-Mails verschickt", klingt nicht danach, als hätte sie diese Genauigkeit verdient. Sie bekommt sie trotzdem — aus demselben Grund wie viele kleine, unscheinbare Integrationspunkte: nicht weil ein einzelner Teil schwierig wäre, sondern weil sie genau zwischen einer gesetzlichen Frist, einem organisationsübergreifenden Kommunikationsschritt und einer kundenseitigen Bestätigung liegt, die das System, einmal verschickt, nicht mehr zurücknehmen kann.
