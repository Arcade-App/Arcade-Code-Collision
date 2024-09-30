using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class PastTournamentButton : MonoBehaviour
{

    [Header("Tournament Data")]
    public int tournamentId;
    public int userId;
    public int gameId;
    public string tournamentName;
    public string tournamentHostName;
    public string socialLink;
    public float playerJoiningFee;
    public int startDate;
    public int startTime;
    public int endDate;
    public int endTime;
    public float prizePool;
    public int status;
    public int playCount;
    public int userCount;
    public float winnerId;
    public float runnerUpId;
    public float secondRunnerUpId;

    [Space(10)]
    public TMP_Text pastTournamentButtonTitleText;
    public TMP_Text pastTournamentPrizePoolText;
    public TMP_Text pastTournamentTimeRemainingText;
    public TMP_Text pastTournamentPlayingText;
    public Image pastTournamentImage;
    public Image pastTournamentButtonImage;


    public Sprite pastTournamentSprite;
    public Color pastTournamentColor;


    public IEnumerator PopulateTournamentData()
    {
        pastTournamentButtonTitleText.text = tournamentName;
        pastTournamentPrizePoolText.text = Manager.instance.canvasManager.TruncateToTwoDecimalPlaces(prizePool) + " APT";

        string startDateString = startDate.ToString();
        string startTimeString = startTime.ToString();
        string endDateString = endDate.ToString();
        string endTimeString = endTime.ToString();

        pastTournamentTimeRemainingText.text = Manager.instance.canvasManager.GetEventStatus(startDateString, startTimeString, endDateString, endTimeString);

        //pastTournamentPlayingText.text = userCount + " playing";

        ////Get Tournament Image
        //// - same as game template image
        //// - get game id for tournament 
        //// - get corr game template id for the game id from the userGameList
        //// - set the image from gameTemplateImageList

        yield return StartCoroutine(Manager.instance.webManager.GetGameTemplateId(gameId));
        

        //int gameIdIndex = Manager.instance.gameDataManager.userGameIdList.IndexOf(gameId);
        //int gameTemplateId = Manager.instance.gameDataManager.userGameTemplateIdList[gameIdIndex];
        pastTournamentSprite = Manager.instance.gameDataManager.gameTemplateImageList[Manager.instance.tournamentDataManager.gameTemplateId];
        pastTournamentImage.sprite = pastTournamentSprite;

        pastTournamentColor = Manager.instance.gameDataManager.gameTemplateColorList[Manager.instance.tournamentDataManager.gameTemplateId];
        pastTournamentButtonImage.color = pastTournamentColor;

    }


    public void OnPastTournamentButtonClicked()
    {
        //Do something 
        StartCoroutine(Manager.instance.canvasManager.OnPastTournamentCanvasButtonClicked(tournamentId, gameId, tournamentName, tournamentHostName, socialLink,
                                            playerJoiningFee, startDate, startTime, endDate, endTime, prizePool,
                                            status, playCount, userCount, winnerId, runnerUpId, secondRunnerUpId,
                                            pastTournamentSprite, pastTournamentColor));

    }


}
