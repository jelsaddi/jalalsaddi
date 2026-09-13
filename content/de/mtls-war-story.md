---
title: "Die mTLS-Geschichte: Ein Trust Store, zwei Secret-Manager und ein Passwort, das es eigentlich nicht geben darf"
date: "2026-09-12"
description: "Ein Zahlungsdienstleister verlangte Mutual TLS. Aus 'einfach ein Zertifikat hinzufügen' wurde eine Trust-Store-Falle, zwei konkurrierende Secret-Sync-Mechanismen im selben Cluster und ein Passwort, das Azure einfach verwirft."
tags: ["mTLS", "Kubernetes", "Security", "Azure"]
image: "/mtlsWarStory.jpeg"
featured: true
---

# Die mTLS-Geschichte: Ein Trust Store, zwei Secret-Manager und ein Passwort, das es eigentlich nicht geben darf

Angefangen hat alles mit einer Fehlermeldung, die ich in dieser Form noch nie gesehen hatte: `PKIX path building failed`. Eine Zahlungsdienstleister-Integration, die ich gerade anband, verlangte für einige ihrer API-Endpunkte Mutual TLS – und mein erster Aufruf gegen die Sandbox scheiterte nicht mit einem 401, nicht mit einem Timeout, sondern schon beim reinen TLS-Handshake. Die zwei Seiten konnten sich nicht einmal darauf einigen, überhaupt miteinander zu sprechen.

Client-Zertifikate hatte ich schon oft eingebaut. Diese Aufgabe entpuppte sich als etwas ganz anderes und zog mich tief hinein in Kubernetes-Secret-Verdrahtung, eine JVM-Trust-Store-Falle und eine Entdeckung, die ich so nicht erwartet hatte: derselbe Cluster fuhr zwei völlig unabhängige Wege, um Secrets aus demselben Vault-Verbund herauszuholen.

## Zwei Probleme unter einem Namen

Mutual TLS klingt nach einer Sache, ist aber eigentlich zwei getrennte Verpflichtungen. Die eigene Seite muss *beweisen, wer sie ist* – mit einem signierten Client-Zertifikat. Und sie muss *demjenigen vertrauen, mit dem sie spricht* – indem sie dessen Server-Zertifikat akzeptiert. Bei den allermeisten TLS-Verbindungen berührt man nur die zweite Hälfte, weil die JVM ohnehin alle gängigen öffentlichen CAs kennt. Bei mTLS müssen beide Richtungen explizit konfiguriert werden – und jede Hälfte hatte eine völlig andere Art, kaputtzugehen.

Die Client-Zertifikat-Hälfte war konzeptionell die einfachere: ein PKCS#12-Keystore laden und der `Configuration` des SDKs übergeben, fertig. Das SDK bot dafür einen sauberen, instanzbezogenen Hook – das Zertifikat wirkte also ausschließlich auf diesen einen API-Client, ohne irgendetwas anderes im Prozess zu beeinflussen.

Spannend wurde es bei der Server-Vertrauens-Hälfte. Die mTLS-Endpunkte des Zahlungsdienstleisters präsentieren eine Zertifikatskette, signiert von einer eigenen, privaten Root-CA – einer CA, die genau für diesen Zweck existiert und verständlicherweise in keinem öffentlichen Trust Store auftaucht. Ein Blick ins SSL-Debug-Log (`-Djavax.net.debug=ssl:handshake`) bestätigte es: kein fehlerhaftes Zertifikat, sondern ein klares "ich kenne den Aussteller nicht".

## Warum man einen JVM-Trust-Store niemals ersetzt

Der naheliegende Fix – `javax.net.ssl.trustStore` auf einen Keystore zeigen zu lassen, der nur die Root-CA des Anbieters enthält – ist gleichzeitig eine hervorragende Methode, jede andere ausgehende HTTPS-Verbindung der JVM stillschweigend zu zerstören. Suchverbindungen, jede andere Drittanbieter-API, alles, was Standard-TLS nutzt – all das verlässt sich auf den Standard-Satz vertrauenswürdiger Root-CAs der JVM. Ersetzt man den Trust Store komplett, tauscht man einen sichtbaren TLS-Fehler in einer Integration gegen einen deutlich größeren, viel schwerer zu diagnostizierenden Ausfall an ganz anderer Stelle.

Die tatsächlich funktionierende Lösung ist unspektakulärer, als sie sich anfühlt, wenn man sie gefunden hat: den *bestehenden* Standard-Trust-Store der JVM laden, die Root-CA des Anbieters oben draufsetzen, und das zusammengeführte Ergebnis als neuen Trust Store schreiben, den die JVM anschließend verwendet. Dieselben vertrauenswürdigen CAs wie vorher, plus eine zusätzliche. Eine Lösung, die im Nachhinein fast zu simpel wirkt – und genau deshalb übersieht man sie leicht, wenn man vor einem Stacktrace sitzt und ein exotischeres Problem vermutet.

Ein Detail, das man sich merken sollte: Das Server-Zertifikat des Anbieters war kein einzelnes Zertifikat, sondern eine Kette – ein Zwischenzertifikat plus ein Root. Hätte man die API-Methode zum Parsen *eines* Zertifikats verwendet, wäre stillschweigend alles außer dem ersten Eintrag verloren gegangen. Die Variante, die eine ganze Sammlung parst, und eine Schleife über das Ergebnis lösten das Problem so, dass der Code nie wissen oder fest verdrahten musste, wie viele Zertifikate in dieser Kette stecken.

## Wo die Zertifikate wirklich liegen

Weder das Client-Zertifikat noch die vertrauenswürdige Root-CA liegen in der Nähe des Anwendungscodes. Beide liegen in Azure Key Vault, werden als native Kubernetes-`Secret`-Objekte synchronisiert und landen als ganz gewöhnliche Umgebungsvariablen in den laufenden Containern. Der Code, der sie liest, weiß nichts von der Existenz eines Vaults – er liest zwei Base64-kodierte Umgebungsvariablen und dekodiert sie. Diese Entkopplung erwies sich als eine der wertvolleren Design-Entscheidungen im gesamten Projekt: derselbe Codepfad funktioniert unabhängig davon, ob der Wert aus einer echten Vault-Synchronisierung in einer verwalteten Umgebung stammt oder für die lokale Entwicklung von Hand in eine Shell exportiert wurde.

Genau diese Entkopplung ließ mich auch etwas entdecken, mit dem ich zu Beginn nicht gerechnet hatte: **Zwei völlig verschiedene Anwendungen im selben Cluster, die aus derselben Vault-Familie lesen, benutzen zwei voneinander unabhängige Mechanismen, um an ihre Secrets zu kommen.** Der eine Dienst nutzt den External Secrets Operator – einen Kubernetes-nativen Controller, der den Vault beobachtet und ein `Secret`-Objekt nach eigenem Zeitplan synchron hält. Der andere Dienst nutzt den Secrets Store CSI Driver, der Vault-Secrets als Dateien in einen Pod mountet und dafür ein kleines, dauerhaft laufendes Hilfs-Deployment braucht, dessen einzige Aufgabe darin besteht, dieses Mounten zu erzwingen, damit die Werte anschließend in ein natives `Secret`-Objekt projiziert werden, auf das andere Pods zugreifen können.

Nichts in der Plattform erzwingt hier Konsistenz – es ist schlicht so gewachsen, von unterschiedlichen Teams, zu unterschiedlichen Zeitpunkten. Erst als klar wurde, *warum* die eigene Dokumentation des einen Ansatzes den Operator dem CSI-Treiber vorzieht – kein dauerhaft laufender Hilfs-Pod nötig, die Synchronisierung läuft nach eigenem Intervall statt auf einen externen Auslöser zu warten – ergab die Uneinheitlichkeit mehr Sinn als gewachsene Geschichte statt als Versehen. Aber das findet man nur, wenn man die beiden YAML-Dateien tatsächlich nebeneinanderlegt, nicht indem man ein Architekturdokument liest, das nur eine der beiden Varianten beschreibt.

## Das Passwort, das Azure stillschweigend löscht

Der seltsamste Moment im ganzen Projekt war die Erkenntnis, dass das Keystore-Passwort neben dem Client-Zertifikat im Key Vault absichtlich ein leerer String war. Das ist tatsächlich dokumentiertes Verhalten, wenn man danach sucht: Importiert man ein passwortgeschütztes Zertifikat in einen solchen Zertifikatsspeicher-Dienst, wird das Import-Passwort nicht gespeichert. Es wurde nur für den einmaligen Importvorgang gebraucht. Jeder spätere Lesezugriff auf das zugrunde liegende Material dieses Zertifikats liefert kein Passwort zurück – unabhängig davon, was man ursprünglich verwendet hat.

Der Code musste also so geschrieben werden, dass "kein Passwort" der *normale* Fall ist, nicht ein Fehlerzustand – ein leeres Passwort ist kein Platzhalter für "hat jemand vergessen einzutragen", sondern jedes Mal der erwartete, korrekte Wert. Und der Passwort-Eintrag muss trotzdem als leerer String bestehen bleiben, statt komplett zu fehlen, weil die Verdrahtung, die diese Werte als Umgebungsvariablen injiziert, einen festen Satz an Schlüsseln erwartet; ein fehlender Schlüssel führt zu einem harten Fehler beim Containerstart – ein deutlich schlechterer Ausfallmodus als ein Zertifikat, das mit leerem Passwort lädt, womit die Anwendung ohnehin schon umzugehen weiß.

Selbst einen leeren String überhaupt erst in den Vault zu bekommen, hatte seine eigene kleine Falle: Das CLI-Tool behandelt ein leeres `--value ""` als "kein Wert angegeben" und lehnt den Befehl schlicht ab, statt es als "explizit auf leer gesetzt" zu interpretieren. Der Workaround – den leeren Wert in eine temporäre Datei schreiben und von dort hochladen statt über die Kommandozeile – ist einer dieser Fünf-Minuten-Fixes, für den man vorher fünfundvierzig Minuten verwirrt debuggt.

## Das Erneuerungsproblem – einfacher gedacht, als es war

Client-Zertifikate laufen ab, in unserem Fall etwa jährlich, und irgendwann muss jemand einen neuen Certificate Signing Request erzeugen, signieren lassen und in jeder Umgebung neu ausrollen. Klingt nach einem Skript, das man einmal schreibt und dann vergisst. Größtenteils stimmt das auch – bis auf eine Subject-Zeilen-Eigenheit, die echte Debugging-Zeit gekostet hat: Unter Windows schreibt Git Bash einen führenden Schrägstrich in einem CSR-Subject-String stillschweigend in etwas um, das aussieht wie ein Windows-Dateipfad, bevor das eigentliche TLS-Tooling den String überhaupt zu Gesicht bekommt. Die resultierende Fehlermeldung liest sich wie ein Syntaxproblem im Subject-String, obwohl in Wirklichkeit eine Shell-Umgebungsvariable die Eingabe verstümmelt. Der Fix ist eine einzige Umgebungsvariable am Anfang des Skripts; herauszufinden, *warum* dieser Fix nötig war, hat deutlich länger gedauert als ihn zu schreiben.

Das Erneuerungs-Tooling musste außerdem einen dritten Konsumenten derselben Zertifikate berücksichtigen, der überhaupt nicht ins Bild passte: ein älterer Dienst, der seine Kopie derselben Zugangsdaten als reine SQL-Konfigurationseinträge im Klartext speichert – direkt ins Repository committet, kein Vault, keine automatisierte Rotation, das echte Passwort im Klartext in der Versionskontrolle. Das wurde in diesem Projekt nicht behoben; es ist ein bekanntes, bewusst dokumentiertes Risiko, das unabhängig von der mTLS-Arbeit besteht und ihr vorausgeht – ehrlich festgehalten, statt es entweder stillschweigend zu ignorieren oder unter Zeitdruck mit etwas "repariert" zu werden, das ohnehin verworfen werden müsste, sobald sich die Secret-Speicherung dieses Dienstes irgendwann ändert.

## Was tatsächlich hängen geblieben ist

Ein paar Dinge aus diesem Projekt nehme ich mit in die nächste Integration, die Mutual TLS braucht:

**Den Code vom Ort der Secrets entkoppeln.** Sobald der Anwendungscode nur noch eine Umgebungsvariable liest, statt direkt mit einem Vault-SDK zu sprechen, durchlaufen lokale Entwicklung, CI und Produktion exakt denselben Codepfad. Diese eine Entscheidung hat mehr Debugging-Zeit gespart als alles andere in dieser Geschichte.

**Eine JVM-weite Ressource niemals ersetzen – immer zusammenführen.** Alles, was `javax.net.ssl.trustStore` oder eine andere JVM-globale System-Property berührt, hat einen Wirkungsradius, der weit über die eigene Integration hinausgeht. Bestehendes laden, ergänzen, zusammengeführt zurückschreiben.

**Koexistierende Secret-Mechanismen im selben Cluster sind häufiger, als man denkt – und gehören explizit dokumentiert.** Wenn zwei Dienste das Problem "Secret aus dem Vault holen" unterschiedlich lösen, ist das nicht automatisch ein Bug. Aber genau das sollte irgendwo schriftlich festgehalten sein, sonst verliert die nächste Person, die ein veraltetes Secret debuggt, eine Stunde damit herauszufinden, welcher Mechanismus überhaupt für welchen Pod zuständig ist.

**Wenn ein Passwort verschwindet, erst prüfen, ob das dokumentiertes Verhalten ist, bevor man einen Bug vermutet.** Der leere Passwort-Fall sah auf den ersten Blick exakt wie eine Fehlkonfiguration aus. War er nicht – die Plattform verhielt sich korrekt, und der Fix lag darin, wie der Anwendungscode "leer" interpretiert, nicht darin, ein Passwort wiederherzustellen, das von Anfang an nicht abrufbar war.

Mutual TLS hat seinen Ruf als mühsam nicht, weil ein einzelner Teil davon schwierig wäre, sondern weil es genau an der Schnittstelle von Kryptografie, Cloud-Secret-Management und Kubernetes-Verdrahtung sitzt – drei Ebenen mit jeweils eigenen, stillen Konventionen, von denen keine einem sagt, wann man gerade gegen eine der anderen verstoßen hat.
