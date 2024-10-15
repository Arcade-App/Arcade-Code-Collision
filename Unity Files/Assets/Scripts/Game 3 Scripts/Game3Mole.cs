using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Game3Mole : MonoBehaviour
{
    public bool isGoodMole;          // Set this in the inspector or dynamically when spawning
    public float riseTime = 0.5f;    // Time it takes to rise
    public float stayTime = 1.5f;    // Time mole stays visible
    public float sinkTime = 0.5f;    // Time it takes to sink

    private Vector3 hiddenPosition;  // Position when mole is hidden
    private Vector3 visiblePosition; // Position when mole is visible
    private bool isActive = false;

    public AudioClip moleAudioClip;
    public AudioSource moleAudioSource;

    void Start()
    {

        if (isGoodMole)
        {
            // Set positions based on initial position
            hiddenPosition = transform.position - Vector3.up * 0.2f;
            visiblePosition = hiddenPosition + Vector3.up * 0.4f;
        }
        else
        {
            // Set positions based on initial position
            hiddenPosition = transform.position - Vector3.up * 0.2f;
            visiblePosition = hiddenPosition + Vector3.up * 0.45f;

        }

        // Start the mole's behavior
        StartCoroutine(MoleRoutine());
    }

    private IEnumerator MoleRoutine()
    {
        isActive = true;

        Debug.Log("hiddenPosition: " + hiddenPosition);

        // Rise
        yield return MoveMole(hiddenPosition, visiblePosition, riseTime);

        // Stay
        yield return new WaitForSeconds(stayTime);

        Debug.Log("visiblePosition: " + visiblePosition);
        // Sink
        yield return MoveMole(visiblePosition, hiddenPosition, sinkTime);

        if (isGoodMole && isActive)
        {
            // Good mole was not hit before disappearing - trigger game over
            Debug.Log("Good mole missed! Game Over!");
            Game3Manager.Instance.GameOver();
        }

        isActive = false;

        // Destroy mole after it completes its routine
        Destroy(gameObject);
    }

    private IEnumerator MoveMole(Vector3 start, Vector3 end, float duration)
    {
        float elapsed = 0f;

        while (elapsed < duration)
        {
            transform.position = Vector3.Lerp(start, end, elapsed / duration);
            elapsed += Time.deltaTime;
            yield return null;
        }

        transform.position = end;
    }

    void OnMouseDown()
    {
        if (!isActive) return;

        if (isGoodMole)
        {
            // Correct mole hit - you can add score logic here
            Debug.Log("Good mole hit!");
            Debug.Log("Score +10");

            moleAudioSource.PlayOneShot(moleAudioClip);

            Manager.instance.gameManager.currentScore += 10;
            Manager.instance.gameManager.uiOngoingScoreTextArray[2].text = Manager.instance.gameManager.currentScore.ToString();
            GetComponent<SpriteRenderer>().enabled = false;
            isActive = false;
        }
        else
        {
            // Wrong mole hit - trigger game over
            Debug.Log("Bad mole hit! Game Over!");
            moleAudioSource.PlayOneShot(moleAudioClip);
            Game3Manager.Instance.GameOver();
            isActive = false;
        }

        // Stop mole routine and destroy it
        StopAllCoroutines();
        Destroy(gameObject, 1f);
    }


}
