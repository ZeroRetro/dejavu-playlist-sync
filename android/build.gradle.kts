allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "just_audio") {
        tasks.matching { it.name.startsWith("compile") }.configureEach {
            doFirst {
                val audioPlayerFile = file("src/main/java/com/ryanheise/just_audio/AudioPlayer.java")
                if (audioPlayerFile.exists()) {
                    var content = audioPlayerFile.readText()
                    var modified = false

                    // 1. Disable hardware audio offload sink crash on Android 15/17
                    val offloadTarget = ".setAudioOffloadMode(AudioOffloadPreferences.AUDIO_OFFLOAD_MODE_ENABLED)"
                    val offloadReplacement = ".setAudioOffloadMode(offloadSchedulingEnabled ? AudioOffloadPreferences.AUDIO_OFFLOAD_MODE_ENABLED : AudioOffloadPreferences.AUDIO_OFFLOAD_MODE_DISABLED)"
                    if (content.contains(offloadTarget)) {
                        content = content.replace(offloadTarget, offloadReplacement)
                        modified = true
                        logger.lifecycle("Patched just_audio AudioPlayer.java to support AudioOffloadPreferences.AUDIO_OFFLOAD_MODE_DISABLED.")
                    }

                    // 2. Add onMediaItemTransition and modernize onPositionDiscontinuity to guarantee auto-advance index sync
                    val transitionTarget = "    @Override\n    public void onPositionDiscontinuity(PositionInfo oldPosition, PositionInfo newPosition, int reason) {\n        updatePosition();\n        switch (reason) {\n        case Player.DISCONTINUITY_REASON_AUTO_TRANSITION:\n        case Player.DISCONTINUITY_REASON_SEEK:\n            updateCurrentIndex();\n            break;\n        }\n        broadcastImmediatePlaybackEvent();\n    }"
                    val transitionReplacement = """    @Override
    public void onMediaItemTransition(MediaItem mediaItem, int reason) {
        updatePosition();
        if (updateCurrentIndex()) {
            broadcastImmediatePlaybackEvent();
        }
    }

    @Override
    public void onPositionDiscontinuity(PositionInfo oldPosition, PositionInfo newPosition, int reason) {
        updatePosition();
        if (newPosition.mediaItemIndex != C.INDEX_UNSET) {
            currentIndex = newPosition.mediaItemIndex;
        } else {
            updateCurrentIndex();
        }
        broadcastImmediatePlaybackEvent();
    }"""
                    if (content.contains(transitionTarget)) {
                        content = content.replace(transitionTarget, transitionReplacement)
                        modified = true
                        logger.lifecycle("Patched just_audio AudioPlayer.java with onMediaItemTransition for gapless auto-advance synchronization.")
                    }

                    if (modified) {
                        audioPlayerFile.writeText(content)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
