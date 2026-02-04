import '../models/mcq_question_model.dart';

class MCQQuestionsData {
  static List<MCQQuestionModel> getAlzheimersQuestions() {
    return [
      MCQQuestionModel(
        id: '1',
        question: 'What is the most common early symptom of Alzheimer\'s disease?',
        options: [
          'Memory loss that disrupts daily life',
          'Difficulty with balance',
          'Vision problems',
          'Hearing loss',
        ],
        correctAnswerIndex: 0,
        explanation: 'Memory loss that disrupts daily life is the most common early symptom of Alzheimer\'s disease.',
      ),
      MCQQuestionModel(
        id: '2',
        question: 'Which of the following is NOT a recommended approach when communicating with a person with Alzheimer\'s?',
        options: [
          'Use simple, clear sentences',
          'Speak loudly and slowly',
          'Maintain eye contact',
          'Ask multiple questions at once',
        ],
        correctAnswerIndex: 3,
        explanation: 'Asking multiple questions at once can be overwhelming and confusing for a person with Alzheimer\'s.',
      ),
      MCQQuestionModel(
        id: '3',
        question: 'What should you do if a person with Alzheimer\'s becomes agitated?',
        options: [
          'Raise your voice to get their attention',
          'Stay calm and try to redirect their attention',
          'Leave them alone',
          'Argue with them to correct their confusion',
        ],
        correctAnswerIndex: 1,
        explanation: 'Staying calm and redirecting attention is the best approach when dealing with agitation.',
      ),
      MCQQuestionModel(
        id: '4',
        question: 'How often should a person with Alzheimer\'s be encouraged to engage in physical activity?',
        options: [
          'Once a week',
          'Only when they want to',
          'Daily, as tolerated',
          'Never, to avoid falls',
        ],
        correctAnswerIndex: 2,
        explanation: 'Daily physical activity, as tolerated, is beneficial for maintaining physical and mental health.',
      ),
      MCQQuestionModel(
        id: '5',
        question: 'What is the best way to help a person with Alzheimer\'s maintain their independence?',
        options: [
          'Do everything for them',
          'Provide support only when needed',
          'Never assist them',
          'Take away all responsibilities',
        ],
        correctAnswerIndex: 1,
        explanation: 'Providing support only when needed helps maintain independence while ensuring safety.',
      ),
      MCQQuestionModel(
        id: '6',
        question: 'Which activity is most beneficial for cognitive stimulation in Alzheimer\'s patients?',
        options: [
          'Watching TV all day',
          'Engaging in familiar activities they enjoy',
          'Learning completely new skills',
          'Avoiding all mental activities',
        ],
        correctAnswerIndex: 1,
        explanation: 'Familiar activities that the person enjoys are most beneficial for cognitive stimulation.',
      ),
      MCQQuestionModel(
        id: '7',
        question: 'What should you do if a person with Alzheimer\'s refuses to eat?',
        options: [
          'Force them to eat',
          'Identify the cause and address it',
          'Skip meals',
          'Only offer liquids',
        ],
        correctAnswerIndex: 1,
        explanation: 'Identifying and addressing the underlying cause is important when dealing with refusal to eat.',
      ),
      MCQQuestionModel(
        id: '8',
        question: 'How should you handle wandering behavior in a person with Alzheimer\'s?',
        options: [
          'Lock them in a room',
          'Provide a safe environment and supervision',
          'Ignore the behavior',
          'Scold them for wandering',
        ],
        correctAnswerIndex: 1,
        explanation: 'Providing a safe environment and supervision is the best approach to handle wandering.',
      ),
      MCQQuestionModel(
        id: '9',
        question: 'What is the recommended approach for managing sleep disturbances in Alzheimer\'s patients?',
        options: [
          'Use sleeping pills every night',
          'Establish a regular routine and limit daytime naps',
          'Let them sleep whenever they want',
          'Wake them up frequently during the night',
        ],
        correctAnswerIndex: 1,
        explanation: 'Establishing a regular routine and limiting daytime naps helps manage sleep disturbances.',
      ),
      MCQQuestionModel(
        id: '10',
        question: 'What is the most important aspect of caregiving for Alzheimer\'s patients?',
        options: [
          'Following a strict schedule',
          'Maintaining patience, empathy, and flexibility',
          'Correcting all mistakes immediately',
          'Avoiding emotional connections',
        ],
        correctAnswerIndex: 1,
        explanation: 'Patience, empathy, and flexibility are the most important aspects of caregiving for Alzheimer\'s patients.',
      ),
    ];
  }
}

