## Background
My country of origin is mainland China, and I am a transgender woman. I am currently receiving professional transgender healthcare in Canada. However, in some regions, including mainland China, due to various unique factors, transgender healthcare resources are extremely scarce, with an increasing number of doctors choosing to close their practice, and systematic hormone replacement therapy (HRT) support is even more limited.

The initial purpose of this application is to alleviate this predicament to some extent, particularly for transgender women living in the margins, through supportive methods, and it is also applicable to all transgender women.

The name of this project, "Kamaboko," comes from a symbolic code popular in mainland China. Because it is difficult to directly express transgender identity in the context of mainland China, transgender women often use the image of Fish Cake as an identification code. This is because the image is similar to the packaging of the estrogen product Progynova sold in mainland China. The Japanese Romanized name for Fish Cake is Kamaboko.

## What it does
Kamaboko aims to help transgender women manage their hormone replacement therapy (HRT) more effectively. It supports daily check-ins, medication planning, hormone level tracking, trend visualization, report recording and interpretation, and generates concise and clear reports for easy communication with doctors. It is suitable for all transgender women receiving hormone replacement therapy, especially those living in areas with limited transgender healthcare resources.

This application does not have direct prescription or dosage advice, but through recording, reminders, supplementary interpretation, and guidance, we hope to provide even a little support and help to more transgender people living on the margins.

Building on this, we have added RLE support features, hoping to provide care and support to transgender women, especially those living in difficult circumstances, through AI analysis and companionship.
## How we built it
When developing this app, I chose SwiftUI as the primary UI framework because of its declarative architecture and high integration with the Apple ecosystem. This allowed me to efficiently build a structured and scalable interface.

For local data persistence, I chose SwiftData to ensure all user information is securely stored on the device, supporting the app's privacy-first design philosophy.

To help users organize lab reports more efficiently, I implemented on-device OCR functionality using Apple's Vision framework. This allows the app to recognize hormone levels in uploaded lab report images without a network connection. All image processing is done locally, ensuring sensitive medical data never leaves the device.

We only network a minimal amount of information to the AI ​​model for analysis generation, maximizing user privacy.

## What we learned
These experiences have shown me that technology is not only a tool for innovation, but also a means of protection, empowerment, and advocacy. Combining technical skills with human rights work is a responsibility I intend to continue pursuing.
## What's next for Kamaboko
The hackathon only lasted a few dozen hours, and due to time constraints and I am just high school student, the project is currently only a draft. In the future, I will improve the functionality, add community features, and collaborate with more resources.
